# frozen_string_literal: true

module CharacterSkills
  module Build
    # Runs the character-skill build over a set of characters. Every entry point goes through
    # here: the deploy hook (.deploy), the on-save job (CharacterSkills::BuildJob), the editor's
    # Reparse (Granblue::EntityReparser) and rake granblue:build_character_skills.
    #
    #   write:  the status catalogue is refreshed, then each stale character is built and
    #           written (Writer) in its own savepoint and its fingerprint stored. One that
    #           raises keeps its rows, is counted and logged, and stays stale. The icon stems
    #           the run created or changed are queued for download once (IconDownloadJob).
    #   shadow: the same, inside one transaction that's rolled back; prints a summary and the
    #           differences grouped as structure / icon / name / description / effects / other.
    #
    # Scope: characters with a non-blank wiki_raw or existing skills; ids: (granblue_ids,
    # both styles) narrows it, characters: (records, used as loaded, unsaved text included)
    # replaces it. Stale: the Fingerprint differs from the stored one; all: true builds
    # every character in scope.
    #
    # Never deletes from a missing source: a character with existing skills and a blank
    # wiki_raw is reported as no_source, and one whose build comes out empty as empty; neither
    # is written nor fingerprinted.
    #
    # Each Summary#results entry carries the character's writer report, its changes (Diff, the
    # C6 `changes`) and icon_fallbacks, for callers that report per character (PR 5's refresh).
    #
    # Instant statuses a build counted as buffs or debuffs (D56: mentioned with a duration, or
    # described as lasting) are listed after the summary line in both modes, for review.
    class Runner
      MODES = %w[shadow write].freeze
      LOAD_BATCH = 50

      # status: built | failed | no_source | empty
      Result = Struct.new(:character, :status, :report, :changes, :icon_fallbacks, :error, keyword_init: true) do
        def changed? = changes.present?
      end

      Summary = Struct.new(:mode, :in_scope, :stale, :built, :failed, :errors, :no_source, :empty, :counts,
                           :results, :icon_stems, :statuses, :seconds, :counted_instants, keyword_init: true) do
        def differing = results.count(&:changed?)
        def drift? = differing.positive? || failed.positive? || empty.positive?
      end

      # The deploy hook (db:migrate:with_data), in CHARACTER_SKILL_BUILD's mode.
      #   off:    nothing.
      #   shadow: summary plus the first 50 differences; never raises, so it can't fail a deploy.
      #   write:  builds the stale characters; one that fails keeps its rows and is retried by
      #           the next deploy, and the deploy carries on.
      def self.deploy(mode: CharacterSkills.build_mode, io: $stdout)
        case mode
        when "shadow"
          begin
            new(mode: "shadow", diff_limit: 50, io: io).call
          rescue StandardError => e
            io.puts "build_character_skills (shadow) failed; the deploy continues: #{e.class}: #{e.message}"
            nil
          end
        when "write"
          summary = new(mode: "write", io: io).call
          if summary.failed.positive?
            io.puts "build_character_skills (write): #{summary.failed} characters failed and kept their existing rows"
          end
          summary
        end
      end

      def initialize(mode:, ids: nil, characters: nil, all: false, diff_limit: nil, io: $stdout, # rubocop:disable Metrics/ParameterLists
                     enqueue_icons: true)
        raise ArgumentError, "mode must be one of #{MODES.join(', ')} (got #{mode.inspect})" unless MODES.include?(mode)

        @mode = mode
        @ids = ids.presence&.map(&:to_s)
        @characters = characters && Array(characters)
        @all = all
        @diff_limit = diff_limit
        @io = io
        @enqueue_icons = enqueue_icons
      end

      def call
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Character.reset_column_information # the fingerprint column may be from this deploy's migration
        @summary = Summary.new(mode: @mode, in_scope: 0, stale: 0, built: 0, failed: 0, errors: [], no_source: 0, empty: 0,
                               counts: Writer::Report.zero, results: [], icon_stems: Set.new, counted_instants: [])

        if @mode == "write"
          run
        else
          ActiveRecord::Base.transaction do
            run
            raise ActiveRecord::Rollback
          end
        end

        @summary.seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        @mode == "write" ? enqueue_icon_jobs : Printer.new(@summary, io: @io, limit: @diff_limit).print
        @io.puts summary_line
        print_counted_instants
        print_display_review
        @summary
      end

      # Characters in scope (ids: path), ordered by granblue_id.
      def scope
        relation = Character.with_source(:wiki_raw).or(Character.where(id: CharacterSkill.select(:character_id)))
        relation = relation.where(granblue_id: @ids) if @ids
        relation.order(:granblue_id, :style_swap)
      end

      private

      def run
        @summary.statuses = refresh_statuses
        fingerprints = Fingerprint.new
        targets = @characters ? given_targets(fingerprints) : scoped_targets(fingerprints)
        ids = targets.map(&:first)
        before = Snapshot.capture(ids)
        lookup = Granblue::Parsers::CharacterSkillParser.build_status_lookup
        each_target(targets) { |character, fingerprint| build(character, fingerprint, lookup) }
        after = Snapshot.capture(ids)
        @summary.results.each { |result| result.changes = Diff.between(before[result.character.id], after[result.character.id]) }
      end

      # The catalogue first: EffectParser resolves status names against it, so a new
      # character's effects resolve only once its statuses are in.
      def refresh_statuses
        if @characters
          Granblue::Parsers::StatusCatalogBuilder.build_for(@characters)
        elsif @ids
          Granblue::Parsers::StatusCatalogBuilder.build_for(scope)
        else
          Granblue::Parsers::StatusCatalogBuilder.build_all
        end
      end

      # → [[character id, fingerprint]] for characters given as records.
      def given_targets(fingerprints)
        @given = @characters.index_by(&:id)
        in_scope = @characters.select { |c| c.source_sha256(:wiki_raw) || CharacterSkill.exists?(character_id: c.id) }
        @summary.in_scope = in_scope.size
        candidates = in_scope.filter_map do |character|
          next no_source(character) unless character.source_sha256(:wiki_raw)

          fingerprint = fingerprints.for(character)
          [character.id, fingerprint] if @all || character.character_skill_build_fingerprint != fingerprint
        end
        @summary.stale = candidates.size
        candidates
      end

      # → [[character id, fingerprint]] from the scope, from the sources' stored sha256.
      def scoped_targets(fingerprints)
        wiki = Source.select(1).where(owner_type: Character.polymorphic_name, kind: "wiki_raw", key: "")
                     .where("sources.owner_id = characters.id")
        rows = scope.pluck(:id, :granblue_id, Arel.sql("NOT EXISTS (#{wiki.to_sql})"), :character_skill_build_fingerprint)
        report_unknown_ids(rows.map(&:second))
        @summary.in_scope = rows.size
        blank, sourced = rows.partition { |row| row[2] }
        Character.where(id: blank.map(&:first)).find_each { |character| no_source(character) } if blank.any?
        current = fingerprints.for_relation(Character.where(id: sourced.map(&:first)))
        candidates = sourced.filter_map do |id, _, _, stored|
          [id, current.fetch(id)] if @all || stored != current.fetch(id)
        end
        @summary.stale = candidates.size
        candidates
      end

      # Loads the targets a few at a time, with their sources (wiki_raw_jp is the largest).
      def each_target(targets, &)
        fingerprint_by_id = targets.to_h
        if @given
          fingerprint_by_id.each { |id, fingerprint| yield @given.fetch(id), fingerprint }
        else
          fingerprint_by_id.keys.each_slice(LOAD_BATCH) do |batch|
            Character.where(id: batch).preload(:sources).order(:granblue_id, :style_swap).each { |c| yield c, fingerprint_by_id.fetch(c.id) }
          end
        end
      end

      def build(character, fingerprint, lookup)
        parser = Granblue::Parsers::CharacterSkillParser.new(character, status_lookup: lookup)
        graph = parser.graph
        return empty(character) if graph[:slots].empty? && CharacterSkill.exists?(character_id: character.id)

        writer = Writer.new(character, graph)
        report = nil
        # A savepoint per character: a failed write rolls back that character alone and
        # leaves the surrounding (shadow) transaction usable.
        ActiveRecord::Base.transaction(requires_new: true) do
          report = writer.call
          character.update_columns(character_skill_build_fingerprint: fingerprint) if @mode == "write"
        end
        @summary.counts.merge!(report)
        @summary.counted_instants.concat(parser.counted_instants.map { |instant| instant.merge(character: label(character)) })
        @summary.icon_stems.merge(writer.icon_stems)
        @summary.built += 1
        @summary.results << Result.new(character: character, status: "built", report: report,
                                       icon_fallbacks: icon_fallbacks(graph))
      rescue StandardError => e
        @summary.failed += 1
        @summary.errors << [character.granblue_id, e]
        @summary.results << Result.new(character: character, status: "failed", error: e, icon_fallbacks: [])
        @io.puts "#{label(character)}: #{e.class}: #{e.message.lines.first&.strip}"
      end

      def no_source(character)
        @summary.no_source += 1
        @summary.results << Result.new(character: character, status: "no_source", icon_fallbacks: [])
        @io.puts "#{label(character)}: no wiki_raw; kept its existing skills"
        nil
      end

      def empty(character)
        @summary.empty += 1
        @summary.results << Result.new(character: character, status: "empty", icon_fallbacks: [])
        @io.puts "#{label(character)}: the build made no skills; kept its existing skills"
      end

      # Versions whose game_icon came from the wiki stem rather than game data or the icon
      # snapshot. Needs the Builder to record :game_icon_source on each version hash; until it
      # does, this is empty.
      def icon_fallbacks(graph)
        graph[:slots].flat_map do |slot|
          slot[:versions].filter_map do |version|
            next unless version[:game_icon_source].to_s == "wiki"

            attrs = version[:attrs]
            { kind: slot[:attrs][:kind].to_s, position: slot[:attrs][:position], ordinal: attrs[:ordinal],
              name: { en: attrs[:name_en], ja: attrs[:name_jp] } }
          end
        end
      end

      # A write that set or changed a version's game_icon downloads the new stems and (debounced)
      # re-exports the icon snapshot. A write that changed no icon queues neither.
      def enqueue_icon_jobs
        return if @summary.icon_stems.empty?

        CharacterSkills::IconDownloadJob.perform_later(@summary.icon_stems.to_a.sort) if @enqueue_icons
        CharacterSkills::ExportIconSnapshotJob.schedule
      end

      def report_unknown_ids(found)
        return unless @ids

        unknown = @ids - found
        @io.puts "Not in scope (no wiki_raw or skills): #{unknown.join(', ')}" if unknown.any?
      end

      def label(character)
        "#{character.granblue_id} #{character.name_en}#{' (style)' if character.style_swap}"
      end

      def summary_line
        c = @summary.counts
        "build_character_skills (#{@mode}): #{@summary.in_scope} in scope, #{@summary.stale} " \
          "#{@all ? 'selected' : 'stale'}, #{@summary.built} built, #{@summary.failed} failed, " \
          "#{@summary.no_source} no source, #{@summary.empty} empty; #{@summary.differing} characters differ; " \
          "slots +#{c.slots_created} ~#{c.slots_updated} -#{c.slots_deleted}; " \
          "versions +#{c.versions_created} ~#{c.versions_updated} -#{c.versions_deleted}; " \
          "effects +#{c.effects_created} ~#{c.effects_updated} -#{c.effects_deleted}; " \
          "links +#{c.links_created} -#{c.links_deleted}; #{format('%.1f', @summary.seconds)}s#{statuses_failed}"
      end

      def print_counted_instants
        instants = @summary.counted_instants
        return if instants.empty?

        @io.puts "#{instants.size} instant status mentions counted as buffs or debuffs (D56), for review:"
        instants.each { |i| @io.puts "  #{i[:character]}: #{i[:status]} (#{i[:reason]}) #{i[:raw]}" }
      end

      # Statuses that show the same name and could only be told apart by their display id (D59).
      def print_display_review
        review = @summary.statuses.is_a?(Hash) ? Array(@summary.statuses.dig(:display, :review)) : []
        return if review.empty?

        @io.puts "#{review.size} statuses share a shown name and are qualified by their display id, for review: #{review.join(', ')}"
      end

      # Statuses the catalogue couldn't save (logged by StatusCatalogBuilder; the build goes on).
      def statuses_failed
        failed = @summary.statuses.is_a?(Hash) ? @summary.statuses[:failed].to_i : 0
        failed.positive? ? "; #{failed} statuses failed to save" : ""
      end
    end
  end
end
