# frozen_string_literal: true

module CharacterSkills
  # Display names for the status catalogue (D59). A status's identity is its wiki name
  # (statuses.wiki_name, which name_key normalizes); name_en is what's shown: the wiki name
  # without its trailing level number (Granblue::Parsers::StatusName.display: "Jade Crest 1" →
  # Jade Crest).
  #
  # When two statuses would show the same name ("Asleep 1" and "Asleep"), one keeps it plain and
  # the others get a qualifier (statuses.qualifier) instead of a suffix in the name. The plain one is
  # the status the wiki list gives the plain name to ("Spirit" links to Spirit 5), else a listed one
  # (in wiki-name order). A
  # qualifier comes from, in order: data/statuses/qualifiers.json (wiki name → qualifier, the user's
  # review); "Unlisted" for a status the wiki list doesn't have; the variant kind (turns → Turns,
  # uses → Times, level → Level); the game's display id. Those that fall to the display id are
  # returned for review. (name_en, qualifier) is unique.
  #
  # Plain SQL, so the repair migration can run it without the model's callbacks. Idempotent.
  class StatusDisplayNames
    PATH = Rails.root.join('data/statuses/qualifiers.json')
    KIND_QUALIFIERS = { 'turns' => 'Turns', 'uses' => 'Times', 'level' => 'Level' }.freeze
    UNLISTED = 'Unlisted'

    # → { renamed:, qualified: [{ wiki_name:, name_en:, qualifier:, source: }], review: [wiki names] }
    def self.call(connection = ActiveRecord::Base.connection)
      new(connection).call
    end

    def self.curated(path = PATH)
      return {} unless File.file?(path) && File.size(path).positive?

      JSON.parse(File.read(path)).to_h { |entry| [Status.normalize_name(entry.fetch('wiki_name')), entry.fetch('qualifier').to_s.squish] }
    end

    def initialize(connection)
      @db = connection
      @curated = self.class.curated
    end

    def call
      return { renamed: 0, qualified: [], review: [] } unless @db.column_exists?(:statuses, :qualifier)

      Granblue::Parsers::StatusList.refresh!
      targets = rows.group_by { |row| Status.normalize_name(row[:display]) }.values.flat_map { |group| assign(group) }
      changed = targets.reject { |row| row[:name_en] == row[:display] && row[:qualifier] == row[:target_qualifier] }
      write(changed)

      qualified = targets.select { |row| row[:target_qualifier] }.map do |row|
        { wiki_name: row[:wiki_name], name_en: row[:display], qualifier: row[:target_qualifier], source: row[:source] }
      end
      { renamed: changed.count { |row| row[:name_en] != row[:display] }, qualified: qualified,
        review: qualified.select { |q| q[:source] == :game_id }.map { |q| q[:wiki_name] } }
    end

    private

    attr_reader :db

    def rows
      db.select_all(<<~SQL.squish).to_a.map { |row| prepare(row.symbolize_keys) }
        SELECT id, wiki_name, name_en, qualifier, variant_kind, game_status_id FROM statuses ORDER BY created_at, id
      SQL
    end

    def prepare(row)
      wiki_name = row[:wiki_name].presence || row[:name_en]
      row.merge(wiki_name: wiki_name, display: Granblue::Parsers::StatusName.display(wiki_name),
                listed: Granblue::Parsers::StatusList.resolve(wiki_name).present?)
    end

    # One group of statuses that show the same name: the first stays plain, the rest get qualifiers.
    def assign(group)
      return group.map { |row| row.merge(target_qualifier: nil) } if group.one?

      plain, *others = group.sort_by { |row| [rank(row), row[:wiki_name]] }
      taken = Set.new
      [plain.merge(target_qualifier: nil)] + others.map do |row|
        qualifier, source = qualifier_for(row, taken)
        taken << Status.normalize_name(qualifier)
        row.merge(target_qualifier: qualifier, source: source)
      end
    end

    def rank(row)
      plain = Granblue::Parsers::StatusList.resolve(row[:display])&.base
      return 0 if plain && Status.normalize_name(plain) == Status.normalize_name(row[:wiki_name])

      row[:listed] ? 1 : 2
    end

    def qualifier_for(row, taken)
      candidates = [[@curated[Status.normalize_name(row[:wiki_name])], :curated],
                    [(UNLISTED unless row[:listed]), :unlisted],
                    [KIND_QUALIFIERS[row[:variant_kind]], :variant_kind],
                    [row[:game_status_id].presence, :game_id],
                    [row[:wiki_name][/ (\d+)\z/, 1], :game_id],
                    [row[:id], :game_id]]
      candidates.find { |qualifier, _| qualifier.present? && taken.exclude?(Status.normalize_name(qualifier)) }
    end

    # Two passes, so a swap between two rows never trips the unique (name_en, qualifier) index:
    # each changed row first takes its own id as a placeholder name.
    def write(changed)
      return if changed.empty?

      ids = changed.map { |row| db.quote(row[:id]) }.join(', ')
      db.exec_update("UPDATE statuses SET name_en = id::text, qualifier = NULL WHERE id IN (#{ids})")
      changed.each { |row| update(row[:id], name_en: row[:display], qualifier: row[:target_qualifier]) }
    end

    def update(id, values)
      sets = values.map { |column, value| "#{column} = #{db.quote(value)}" }.join(', ')
      db.exec_update("UPDATE statuses SET #{sets}, updated_at = now() WHERE id = #{db.quote(id)}")
    end
  end
end
