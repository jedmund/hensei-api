# frozen_string_literal: true

require 'csv'

module CharacterSkills
  # rake granblue:character_skill_coverage: what the stored sources and built skills
  # still lack, so every backfill run has a before and an after. Read-only, except the
  # optional S3 check, which makes one HEAD request per distinct icon stem.
  #
  # Every row is a list of items (a character row, a version or an icon stem) counted
  # in total, by rarity and by distinct character row. Gap rows are the work left;
  # the CSV lists their items for the user. Info rows (totals, fetch age) only count.
  class Coverage
    # detail: what the item is when it isn't the character row itself (a version, a stem).
    Item = Struct.new(:granblue_id, :style, :name_en, :rarity, :detail, :owners, keyword_init: true) do
      def character_keys = owners || [[granblue_id, style]]
    end

    Row = Struct.new(:section, :key, :label, :items, :gap, keyword_init: true) do
      def count = items.size
      def characters = items.flat_map(&:character_keys).uniq.size
      def by_rarity(rarity) = items.count { |item| item.rarity == rarity }
    end

    RARITIES = { 1 => 'R', 2 => 'SR', 3 => 'SSR' }.freeze
    ICON_PREFIX = 'icons/abilities/'
    # wiki_raw_fetched_at buckets, in days.
    RECENT_DAYS = 30
    OLD_DAYS = 90
    LABEL_WIDTH = 76
    CSV_HEADERS = %w[check granblue_id style name_en rarity detail].freeze

    # A character's source row of a kind (D35: blank and JSON-null payloads are never stored).
    SOURCE_SQL = "FROM sources WHERE sources.owner_type = 'Character' AND sources.owner_id = characters.id " \
                 "AND sources.key = '' AND sources.kind = '%s'"
    CHARACTER_COLUMNS = [
      'characters.id', 'characters.granblue_id', 'characters.style_swap', 'characters.name_en',
      'characters.rarity', 'characters.release_date', 'characters.wiki_en',
      "(SELECT sources.fetched_at #{format(SOURCE_SQL, 'wiki_raw')})",
      *%w[wiki_raw wiki_raw_jp game_raw_en game_raw_jp].map { |kind| "EXISTS (SELECT 1 #{format(SOURCE_SQL, kind)})" }
    ].freeze
    CHARACTER_FIELDS = %i[id granblue_id style_swap name_en rarity release_date wiki_en fetched_at
                          wiki_raw wiki_raw_jp game_en game_jp skills].freeze

    # Slots belong to a character row (character_id); before that column existed (K1),
    # to the base row of their granblue_id. The second form lets the report run on an
    # older copy of the database.
    OWNER_SQL = {
      character_id: 's.character_id',
      granblue_id: '(SELECT c.id FROM characters c WHERE c.granblue_id = s.character_granblue_id ' \
                   'AND c.style_swap = false ORDER BY c.id LIMIT 1)'
    }.freeze
    HAS_SKILLS_SQL = {
      character_id: 'EXISTS (SELECT 1 FROM character_skills s WHERE s.character_id = characters.id)',
      granblue_id: 'EXISTS (SELECT 1 FROM character_skills s WHERE s.character_granblue_id = characters.granblue_id ' \
                   'AND characters.style_swap = false)'
    }.freeze
    VERSION_FIELDS = %i[character_id kind position ordinal name_en name_jp game_icon].freeze

    def initialize(ids: nil, check_bucket: false, storage: nil, s3_delay: 0.05, today: Date.current, # rubocop:disable Metrics/ParameterLists
                   icon_snapshot_path: IconSnapshot::DEFAULT_PATH, sleeper: ->(seconds) { sleep(seconds) })
      @ids = ids.presence&.map(&:to_s)
      @check_bucket = check_bucket
      @storage = storage
      @s3_delay = s3_delay.to_f
      @today = today
      @icon_snapshot_path = icon_snapshot_path
      @sleeper = sleeper
    end

    def rows
      @rows ||= character_rows + source_rows + style_rows + version_rows + (@check_bucket ? [bucket_row] : [])
    end

    def gaps = rows.select(&:gap)

    def print(io = $stdout)
      io.puts "Character skill coverage, #{@today.iso8601}#{" (ids: #{@ids.join(',')})" if @ids}"
      io.puts '  * = a gap (listed by format=csv)'
      rows.group_by(&:section).each do |section, section_rows|
        io.puts
        io.puts table_line(section, 'total', *RARITIES.values, 'chars')
        section_rows.each do |row|
          io.puts table_line("#{row.gap ? '*' : ' '} #{row.label}", row.count, *RARITIES.keys.map { |r| row.by_rarity(r) },
                             row.characters)
        end
      end
    end

    # The gap rows' items, one per line.
    def to_csv
      CSV.generate do |csv|
        csv << CSV_HEADERS
        gaps.each do |row|
          row.items.each do |item|
            csv << [row.key, item.granblue_id, item.style, item.name_en, RARITIES[item.rarity], item.detail]
          end
        end
      end
    end

    private

    # label, total, R, SR, SSR, chars
    def table_line(label, *counts)
      label.ljust(LABEL_WIDTH) + counts.map.with_index { |count, i| count.to_s.rjust(i.zero? || i == 4 ? 8 : 7) }.join
    end

    def characters
      @characters ||= begin
        scope = Character.order(:granblue_id, :style_swap)
        scope = scope.where(granblue_id: @ids) if @ids
        columns = CHARACTER_COLUMNS + [HAS_SKILLS_SQL.fetch(owner_key)]
        scope.pluck(*columns.map { |column| Arel.sql(column) }).map { |values| CHARACTER_FIELDS.zip(values).to_h }
      end
    end

    def characters_by_id = @characters_by_id ||= characters.index_by { |c| c[:id] }

    def versions
      @versions ||= begin
        sql = <<~SQL.squish
          SELECT #{OWNER_SQL.fetch(owner_key)}, s.kind, s.position, v.ordinal, v.name_en, v.name_jp, v.game_icon
          FROM character_skill_versions v JOIN character_skills s ON s.id = v.character_skill_id
          ORDER BY 1, 2, 3, 4
        SQL
        ActiveRecord::Base.connection.select_rows(sql)
                          .map { |values| VERSION_FIELDS.zip(values).to_h.merge(position: values[2].to_i, ordinal: values[3].to_i) }
                          .select { |version| characters_by_id.key?(version[:character_id]) }
      end
    end

    def owner_key
      @owner_key ||= CharacterSkill.connection.column_exists?(:character_skills, :character_id) ? :character_id : :granblue_id
    end

    def released?(character) = character[:release_date].nil? || character[:release_date] <= @today

    def character_rows
      no_skills = characters.reject { |c| c[:skills] }
      released, unreleased = no_skills.partition { |c| released?(c) }
      [
        row('Characters', :characters, 'Character rows (base and style)', characters),
        row('Characters', :no_skills, 'Released, no skills', released, gap: true),
        row('Characters', :no_skills_unreleased, 'Not released yet (release_date in the future), no skills', unreleased)
      ]
    end

    def source_rows
      with_wiki, blank_wiki = characters.partition { |c| c[:wiki_raw] }
      [
        row('Sources', :wiki_raw_blank, 'Blank wiki_raw', blank_wiki, gap: true) do |c|
          c[:wiki_en].blank? ? 'no wiki_en (needs a page title)' : nil
        end,
        row('Sources', :wiki_raw_present, 'wiki_raw present', with_wiki),
        *fetch_age_rows(with_wiki),
        row('Sources', :no_wiki_raw_jp, 'No wiki_raw_jp', characters.reject { |c| c[:wiki_raw_jp] }, gap: true),
        row('Sources', :no_game_raw_en, 'No game_raw_en (null or JSON null)', characters.reject { |c| c[:game_en] }, gap: true),
        row('Sources', :no_game_raw_jp, 'No game_raw_jp', characters.reject { |c| c[:game_jp] }, gap: true)
      ]
    end

    def fetch_age_rows(with_wiki)
      recent = @today - RECENT_DAYS
      old = @today - OLD_DAYS
      never, stamped = with_wiki.partition { |c| c[:fetched_at].nil? }
      [
        row('Sources', :wiki_raw_fetched_never, '  wiki_raw_fetched_at never set', never),
        row('Sources', :wiki_raw_fetched_old, "  fetched before #{old.iso8601} (> #{OLD_DAYS} days)",
            stamped.select { |c| c[:fetched_at].to_date < old }),
        row('Sources', :wiki_raw_fetched_mid, "  fetched #{old.iso8601} to #{recent.iso8601}",
            stamped.select { |c| c[:fetched_at].to_date >= old && c[:fetched_at].to_date < recent }),
        row('Sources', :wiki_raw_fetched_recent, "  fetched since #{recent.iso8601} (<= #{RECENT_DAYS} days)",
            stamped.select { |c| c[:fetched_at].to_date >= recent })
      ]
    end

    def style_rows
      styles = characters.select { |c| c[:style_swap] }
      [
        row('Style rows', :style_rows, 'Style rows (style_swap)', styles),
        row('Style rows', :style_no_skills, '  with no skills', styles.reject { |c| c[:skills] }),
        row('Style rows', :style_no_wiki_raw, '  with a blank wiki_raw', styles.reject { |c| c[:wiki_raw] }),
        row('Style rows', :style_no_game_raw_en, '  with no game_raw_en (style 2 payload)', styles.reject { |c| c[:game_en] })
      ]
    end

    def version_rows
      abilities = versions.select { |v| v[:kind] == 'ability' }
      [
        version_row(:versions, 'Skill versions (all kinds)', versions),
        version_row(:versions_no_name_jp, 'Versions with no name_jp', versions.select { |v| v[:name_jp].blank? }, gap: true),
        version_row(:ability_versions_no_game_icon, 'Ability versions with no game_icon',
                    abilities.select { |v| v[:game_icon].blank? }, gap: true),
        version_row(:support_versions_no_game_icon, 'Support versions with no game_icon (web shows a static icon)',
                    versions.select { |v| v[:kind] == 'support' && v[:game_icon].blank? }),
        version_row(:ability_versions_wiki_stem_only,
                    'Ability icons from the wiki stem only (no game data, not in the snapshot)',
                    abilities.select { |v| wiki_stem_only?(v) }, gap: true)
      ]
    end

    # The Builder doesn't store where an icon came from, so this is the proxy: the owner
    # has no game_raw_en (no class_name to take it from) and the icon snapshot doesn't
    # give this version that icon, so the wiki page's stem is what's left.
    def wiki_stem_only?(version)
      return false if version[:game_icon].blank?

      owner = characters_by_id[version[:character_id]]
      return false if owner[:game_en]

      key = { granblue_id: owner[:granblue_id], style: owner[:style_swap] ? 2 : 1, kind: version[:kind],
              position: version[:position], ordinal: version[:ordinal] }
      IconSnapshot.icon_for(key, name_en: version[:name_en], path: @icon_snapshot_path) != version[:game_icon]
    end

    # Every stored stem, any kind, as granblue:download_ability_icons downloads them.
    def bucket_row
      by_stem = versions.select { |v| v[:game_icon].present? }.group_by { |v| v[:game_icon] }
      missing = by_stem.keys.sort.each_with_index.reject do |stem, index|
        @sleeper.call(@s3_delay) if index.positive? && @s3_delay.positive?
        storage.file_exists?("#{ICON_PREFIX}#{stem}.png")
      end.map(&:first)

      items = missing.map do |stem|
        users = by_stem[stem]
        owner = characters_by_id[users.first[:character_id]]
        owners = users.map { |v| characters_by_id[v[:character_id]] }.uniq
        Item.new(granblue_id: owner[:granblue_id], style: style_of(owner), name_en: owner[:name_en], rarity: owner[:rarity],
                 detail: "#{stem} (#{users.size} versions, #{owners.size} characters)",
                 owners: owners.map { |c| [c[:granblue_id], style_of(c)] })
      end
      Row.new(section: 'Bucket', key: :ability_stems_missing_from_bucket, gap: true, items: items,
              label: "Stored stems missing from #{ICON_PREFIX} (count = stems)")
    end

    def storage = @storage ||= AwsService.new

    def row(section, key, label, list, gap: false)
      items = list.map do |c|
        Item.new(granblue_id: c[:granblue_id], style: style_of(c), name_en: c[:name_en], rarity: c[:rarity],
                 detail: block_given? ? yield(c) : nil)
      end
      Row.new(section: section, key: key, label: label, items: items, gap: gap)
    end

    def version_row(key, label, list, gap: false)
      items = list.map do |v|
        owner = characters_by_id[v[:character_id]]
        Item.new(granblue_id: owner[:granblue_id], style: style_of(owner), name_en: owner[:name_en], rarity: owner[:rarity],
                 detail: "#{v[:kind]} #{v[:position]}.#{v[:ordinal]} #{v[:name_en]}#{" [#{v[:game_icon]}]" if v[:game_icon]}")
      end
      Row.new(section: 'Skills', key: key, label: label, items: items, gap: gap)
    end

    def style_of(character) = character[:style_swap] ? 2 : 1
  end
end
