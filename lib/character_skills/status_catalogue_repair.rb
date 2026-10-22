# frozen_string_literal: true

module CharacterSkills
  # One status per name, keyed by Status.normalize_name (statuses.name_key), where the name
  # is the wiki name without its variant number (Granblue::Parsers::StatusName: "DEF Down 4"
  # is DEF Down, icon variant 4). Shared by the repair migration and bin/setup-pipeline-db,
  # whose older catalogue dumps still hold duplicate and numbered names.
  #
  # For each status it keeps the row the skill build resolved names to before names were
  # unique (the majority category; ties: field, then buff; a field row beats a buff
  # majority; then the oldest row in it). Effects on a numbered row first get the number as
  # status_variant, then move to the kept row; the others are deleted and the kept row takes
  # the plain name. Then it recomputes family/level from the name and fills name_key. Plain
  # SQL and Ruby, so it doesn't depend on the model's callbacks or on name_key's index.
  class StatusCatalogueRepair
    TIE_ORDER = %w[field buff debuff special].freeze

    def self.call(connection = ActiveRecord::Base.connection)
      new(connection).call
    end

    def initialize(connection)
      @db = connection
    end

    # → { merged_names:, deleted:, effects_repointed:, variants_set:, renamed:, families_fixed:, keys_set: }
    def call
      counts = merge_duplicates
      counts[:families_fixed] = recompute_families
      counts[:keys_set] = fill_name_keys
      counts
    end

    private

    attr_reader :db

    def rows
      db.select_all('SELECT id, name_en, category, family, level, name_key FROM statuses ORDER BY created_at, id').to_a
    end

    def merge_duplicates
      groups = rows.group_by { |row| Status.normalize_name(Granblue::Parsers::StatusName.base(row['name_en'])) }.values
                   .select { |group| group.size > 1 || numbered?(group.first) || aliased?(group.first) }
      counts = { merged_names: groups.count { |group| group.size > 1 }, deleted: 0, effects_repointed: 0,
                 variants_set: 0, renamed: 0 }

      groups.each do |group|
        keep = canonical(group)
        group.each { |row| counts[:variants_set] += variants_to_effects(row) }
        others = group.map { |row| row['id'] } - [keep['id']]
        merge(keep, others, counts) if others.any?
        counts[:renamed] += rename(keep, group)
      end
      counts
    end

    def aliased?(row)
      Granblue::Parsers::StatusName.base(row['name_en']) != row['name_en'].to_s.squish && !numbered?(row)
    end

    def numbered?(row)
      Granblue::Parsers::StatusName.split(row['name_en']).last.present?
    end

    # Effects on "DEF Down 4" keep the 4 as their variant (unless the build already set one),
    # with its kind where the effect's own template says (t= or n=); the build fills the rest.
    def variants_to_effects(row)
      variant = Granblue::Parsers::StatusName.split(row['name_en']).last
      return 0 if variant.nil?

      effects = db.select_all(<<~SQL.squish).to_a
        SELECT id, raw FROM skill_effects WHERE status_id = #{db.quote(row['id'])} AND status_variant IS NULL
      SQL
      effects.sum do |effect|
        kind = Granblue::Parsers::StatusName.mention_kind(variant, template_params(effect['raw']))
        db.exec_update(<<~SQL.squish)
          UPDATE skill_effects SET status_variant = #{db.quote(variant)}, status_variant_kind = #{db.quote(kind)},
                 updated_at = now() WHERE id = #{db.quote(effect['id'])}
        SQL
      end
    end

    def template_params(raw)
      Granblue::Parsers::StatusMentions.in(raw.to_s).first&.params || {}
    end

    def merge(keep, others, counts)
      ids = others.map { |id| db.quote(id) }.join(', ')
      counts[:effects_repointed] += db.exec_update(<<~SQL.squish)
        UPDATE skill_effects SET status_id = #{db.quote(keep['id'])}, updated_at = now() WHERE status_id IN (#{ids})
      SQL
      counts[:deleted] += db.exec_delete("DELETE FROM statuses WHERE id IN (#{ids})")
    end

    # The kept row takes the plain name: an unnumbered row's spelling if the group has one,
    # mapped through the approved aliases (DEF Lowered → DEF Down).
    def rename(keep, group)
      plain = group.find { |row| !numbered?(row) }
      name = Granblue::Parsers::StatusName.base((plain || keep)['name_en'])
      return 0 if name == keep['name_en']

      update(keep['id'], name_en: name, name_key: Status.normalize_name(name), wiki_slug: name.tr(' ', '_'))
    end

    def canonical(group)
      counts = group.filter_map { |row| row['category'] }.tally
      return group.first if counts.empty?

      top = counts.values.max
      tied = counts.select { |_, count| count == top }.keys
      category = TIE_ORDER.find { |c| tied.include?(c) } || tied.min
      category = 'field' if category == 'buff' && counts.key?('field')
      group.find { |row| row['category'] == category } || group.first
    end

    def recompute_families
      rows.count do |row|
        family, level = Status.split_family_and_level(row['name_en'])
        next false if row['family'] == family && row['level'].to_s == level.to_s

        update(row['id'], family: family, level: level).positive?
      end
    end

    def fill_name_keys
      rows.count do |row|
        key = Status.normalize_name(row['name_en'])
        next false if row['name_key'] == key

        update(row['id'], name_key: key).positive?
      end
    end

    def update(id, values)
      sets = values.map { |column, value| "#{column} = #{db.quote(value)}" }.join(', ')
      db.exec_update("UPDATE statuses SET #{sets}, updated_at = now() WHERE id = #{db.quote(id)}")
    end
  end
end
