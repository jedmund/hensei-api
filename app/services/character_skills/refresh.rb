# frozen_string_literal: true

module CharacterSkills
  # An editor's refresh of one character from the wiki (PR 5, contract C6): fetch the
  # current pages without storing them, show what the build would change, then write
  # exactly the text that was shown.
  #
  #   refresh = Refresh.new(character)
  #   sources = refresh.fetch(refetch: true, refetch_jp: false)  # network only, no writes
  #   refresh.preview(sources)  # → C6 `refresh` hash; the build runs in shadow, nothing is written
  #   refresh.apply(sources)    # → C6 `refresh` hash; writes the sources, then builds and writes
  #
  # .preview / .apply_preview keep the sources under a preview token (RefreshStore) for the
  # reparse endpoint; the batch refresh (RefreshBatch) keeps them under the batch.
  class Refresh
    class Error < StandardError; end
    # The token is unknown, expired, someone else's, for another character, or the
    # character's other build inputs changed since the preview.
    class PreviewExpired < Error; end
    # The build was held back (no wikitext, or it made no skills): nothing was written.
    class BuildRefused < Error; end
    # The build raised; nothing was written.
    class BuildFailed < Error; end

    COUNTS = %i[slots_created slots_deleted versions_created versions_updated versions_deleted
                effects_created effects_updated effects_deleted links_created links_deleted].freeze
    # Diff fields that are bookkeeping rather than something an editor reads.
    HIDDEN_FIELDS = %w[duplicates slot_game_action_id].freeze
    EXPIRED_MESSAGE = 'This preview has expired. Preview again to refresh.'
    NO_SOURCE_MESSAGE = 'No stored wikitext — fetch the wiki page first'

    # What a refresh builds from. wiki_raw / wiki_raw_jp are the text the build reads
    # (fetched, or the stored text when that page wasn't fetched); inputs_digest covers the
    # character's other build inputs at fetch time.
    Sources = Struct.new(:wiki_en, :wiki_raw, :wiki_raw_jp, :fetched_en, :fetched_jp, :fetched_at,
                         :inputs_digest, keyword_init: true)

    # → C6 `refresh` with a preview_token, after storing the fetched text under it.
    def self.preview(character, user:, refetch:, refetch_jp:)
      refresh = new(character)
      sources = refresh.fetch(refetch: refetch, refetch_jp: refetch_jp)
      result = refresh.preview(sources)
      token = "pv_#{SecureRandom.hex(16)}"
      RefreshStore.write(preview_key(token), { user_id: user.id, character_id: character.id, sources: sources.to_h },
                         expires_in: RefreshStore::PREVIEW_TTL)
      result.merge(preview_token: token)
    end

    # Writes the sources stored under token (no fetch). Raises PreviewExpired unless the
    # token is this user's preview of this character and nothing else changed since.
    def self.apply_preview(character, user:, token:)
      entry = token.present? && RefreshStore.read(preview_key(token))
      unless entry && entry[:user_id] == user.id && entry[:character_id] == character.id
        raise PreviewExpired, EXPIRED_MESSAGE
      end

      result = new(character).apply(Sources.new(**entry[:sources]))
      RefreshStore.delete(preview_key(token))
      result
    end

    # Today's reparse: fetch what's asked, then write and build, without a preview.
    def self.reparse(character, refetch:, refetch_jp:)
      refresh = new(character)
      refresh.apply(refresh.fetch(refetch: refetch, refetch_jp: refetch_jp), check_inputs: false)
    end

    def self.preview_key(token) = "preview:#{token}"

    def initialize(character, pacer: WikiPacer.instance)
      @character = character
      @pacer = pacer
    end

    # Fetches the asked pages, ≥2s apart per site (WikiPacer). Stores nothing.
    def fetch(refetch:, refetch_jp:)
      sources = Sources.new(wiki_en: @character.wiki_en, wiki_raw: @character.wiki_raw,
                            wiki_raw_jp: @character.wiki_raw_jp, fetched_en: false, fetched_jp: false)
      if refetch
        page = Granblue::WikiFetcher.new.fetch(@character, before_request: @pacer.before_request(:gbf_wiki))
        sources.wiki_en = page.title
        sources.wiki_raw = page.text
        sources.fetched_en = true
      end
      if refetch_jp
        html = Granblue::Downloaders::JpWikiDownloader.new(@character)
                                                      .fetch(before_request: @pacer.before_request(:gbf_wiki_jp))
        raise Granblue::WikiFetcher::MissingPageError, 'No Japanese wiki page could be found for this character' if html.nil?

        sources.wiki_raw_jp = html
        sources.fetched_jp = true
      end
      sources.fetched_at = Time.current.iso8601 if sources.fetched_en || sources.fetched_jp
      sources.inputs_digest = inputs_digest(@character, sources)
      sources
    end

    # Builds the character from sources in shadow mode. Writes nothing: the sources are
    # set on a separate in-memory copy, and the runner rolls its transaction back.
    def preview(sources)
      record = Character.find(@character.id)
      record.wiki_raw = sources.wiki_raw
      record.wiki_raw_jp = sources.wiki_raw_jp
      result = run_build(record, mode: 'shadow')
      to_c6(sources, result, written: false)
    end

    # Writes the fetched sources (wiki_en, wiki_raw, wiki_raw_jp and their fetched_at) and
    # builds the character in write mode, in one transaction: a refused or failed build
    # writes nothing. The on-save build job is suppressed; this build replaces it.
    def apply(sources, check_inputs: true)
      if check_inputs && sources.inputs_digest != inputs_digest(@character.reload, sources)
        raise PreviewExpired, 'This character changed since the preview. Preview again to refresh.'
      end

      changed = text_changes(sources)
      result = Character.without_skill_build do
        ActiveRecord::Base.transaction do
          @character.update!(source_attributes(sources)) if sources.fetched_en || sources.fetched_jp
          run_build(@character, mode: 'write')
        end
      end
      to_c6(sources, result, written: true, changed: changed)
    end

    private

    def run_build(record, mode:)
      summary = Build::Runner.new(mode: mode, characters: [record], all: true, io: StringIO.new).call
      result = summary.results.find { |r| r.character.id == record.id }
      case result&.status
      when 'built' then result
      when 'failed' then raise BuildFailed, result.error.message
      when 'empty' then raise BuildRefused, 'Nothing was written: the build made no skills; kept its existing skills'
      else raise BuildRefused, NO_SOURCE_MESSAGE
      end
    end

    def source_attributes(sources)
      attrs = {}
      if sources.fetched_en
        attrs.merge!(wiki_en: sources.wiki_en, wiki_raw: sources.wiki_raw, wiki_raw_fetched_at: sources.fetched_at)
      end
      if sources.fetched_jp
        attrs[:wiki_raw_jp] = sources.wiki_raw_jp
        attrs[:wiki_raw_jp_fetched_at] = sources.fetched_at
      end
      attrs
    end

    # → { en:, jp: }: whether each fetched page differs from the stored text (nil: not fetched).
    def text_changes(sources)
      {
        en: sources.fetched_en ? sources.wiki_raw != @character.wiki_raw : nil,
        jp: sources.fetched_jp ? sources.wiki_raw_jp != @character.wiki_raw_jp : nil
      }
    end

    def to_c6(sources, result, written:, changed: text_changes(sources))
      {
        preview_token: nil,
        written: written,
        wiki_changed: changed[:en] || false,
        wiki_jp_changed: changed[:jp],
        fetched_at: sources.fetched_at,
        counts: result.report.to_h.slice(*COUNTS),
        changes: changes(result),
        icon_fallbacks: result.icon_fallbacks
      }
    end

    def changes(result)
      result.changes.filter_map do |change|
        item = change.to_h
        item[:fields] = item[:fields] - HIDDEN_FIELDS
        item unless item[:change] == 'updated' && item[:fields].empty?
      end
    end

    # The character's build inputs that the refresh doesn't fetch: if any of them changed
    # between the preview and the apply, the build would differ from what was shown.
    def inputs_digest(character, sources)
      inputs = %w[game_raw_en game_raw_jp jp_skill_text].map { |kind| character.source_sha256(kind) }
      inputs += Build::Fingerprint::ATTRIBUTES.map { |column| character[column] }
      inputs << (sources.fetched_en ? nil : character.source_sha256(:wiki_raw))
      inputs << (sources.fetched_jp ? nil : character.source_sha256(:wiki_raw_jp))
      Digest::SHA256.hexdigest(JSON.generate(inputs))
    end
  end
end
