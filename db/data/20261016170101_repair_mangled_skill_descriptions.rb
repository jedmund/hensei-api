# frozen_string_literal: true

# Shared weapon Skill descriptions that old imports broke, and the version texts copied
# from them. Reads only stored sources (weapon_sources); never the network.
#
# 1. Flattened status icons (30 skills on the 2026-10-15 catalogue). The expansion repair
#    took a skill's text from the expanded page, and its cleaner turned each
#    [[File:…|25px|link=Burned]] icon into "25px|link=Burned…". The per-version backfill
#    then copied that text into 25 versions. Each version's own text is rebuilt from the
#    weapon's stored page: the structure compiler's tier text (ensN_desc, else sN_desc),
#    taken only when it names the same skill at the same slot and ordinal and is clean.
#    The Skill then takes the text of its last tier, the one the old writer would have
#    stored last. A skill with a version that can't be rebuilt is left alone.
# 2. Breaks in the page itself, which the rebuild would only copy, so they're stripped:
#    Hoarfrost's Heed has the next field glued to its line ("…(Big DMG)|s2_name=…"),
#    Wicked Fangs' text sits in a parameter default ("{{{s2_desc|…}}}"), and Blessing
#    Petals ends in stray pipes ("…|t=i}}.|||").
#
# Every write is guarded on the text still being broken, so the migration is idempotent
# and leaves any text fixed since alone.
class RepairMangledSkillDescriptions < ActiveRecord::Migration[8.1]
  ICON = /\d+px\|link=/
  GLUED_FIELD = /(?<=\S)\|(?:en|jp)?s\d(?:_\w+?)?_(?:name|desc|icon|lvl)=.*\z/m
  PARAMETER_DEFAULT = /\A\{\{\{(?:en)?s\d(?:_\w+?)?_desc\|(.*?)\}\}\}(?!\})/m
  TRAILING_PIPES = /\|+\s*\z/

  # The weapon_sources table this read, as a SourceStore. WeaponSource reads `sources` since
  # PR 7b, and 20261022110100 copies weapon_sources there later, so a database that runs this
  # late reads the same pages.
  class StoredSources
    include WeaponSkills::SourceStore::Interface

    def fetch(kind, key)
      key = Granblue::WikiTitle.normalize(key).to_s
      row = ActiveRecord::Base.connection.select_all(ActiveRecord::Base.sanitize_sql([<<~SQL.squish, kind.to_s, key]))
        SELECT kind, key, body, sha256, fetched_at, page_kind FROM weapon_sources
        WHERE kind = ? AND key = ? ORDER BY fetched_at DESC LIMIT 1
      SQL
      raise WeaponSkills::SourceStore::SourceMissing.new(kind, key) if row.empty?

      WeaponSkills::SourceStore::Source.new(**row.first.symbolize_keys)
    end
  end

  def up
    return unless defined?(WeaponSkills::Build::Structure) && table_exists?(:weapon_sources)

    @store = StoredSources.new
    @builds = {}
    Skill.where(skill_type: :weapon).where("description_en ~ ?", '[0-9]+px\|link=').find_each { |s| rebuild(s) }
    # Template-form skills ("{{{s1_4s_name|…}}}", "Sephirath {{#switch:…") are the build's
    # to drop or resolve, not text to tidy.
    Skill.where(skill_type: :weapon).where.not(description_en: nil).find_each do |skill|
      next if skill.name_en.to_s.match?(/[{}]/)

      text = strip(skill.description_en) and skill.update_columns(description_en: text)
    end
    WeaponSkillVersion.includes(:skill).where.not(description_en: nil).find_each do |version|
      next if version.skill.nil? || version.skill.name_en.to_s.match?(/[{}]/)

      text = strip(version.description_en) and version.update_columns(description_en: text)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def rebuild(skill)
    versions = WeaponSkillVersion.where(skill_id: skill.id).includes(:weapon_skill)
                                 .sort_by { |v| [v.weapon_skill.weapon_granblue_id, v.weapon_skill.position, v.ordinal] }
    return if versions.empty?

    texts = versions.to_h do |v|
      own = v.description_en
      [v, own.present? && !own.match?(ICON) ? own : rebuilt_text(v, skill.name_en)]
    end
    if texts.values.any?(&:nil?)
      say "#{skill.name_en}: a version's text can't be rebuilt from stored sources; left as is"
      return
    end

    texts.each { |v, text| v.update_columns(description_en: text) if v.description_en != text }
    skill.update_columns(description_en: texts[versions.last])
  end

  # The version's tier text from the structure compiler, or nil.
  def rebuilt_text(version, name)
    gid = version.weapon_skill.weapon_granblue_id
    built = (@builds[gid] ||= build(gid))
    match = built.find do |b|
      b.position == version.weapon_skill.position && b.ordinal == version.ordinal && b.skill_name_en == name
    end
    text = match&.description_en
    text.present? && !text.match?(ICON) ? text : nil
  end

  def build(gid)
    weapons = Weapon.where(granblue_id: gid).order(:id).to_a
    weapon = weapons.find { |w| w.wiki_en.present? && @store.exist?("wiki_raw", w.wiki_en) } or return []

    WeaponSkills::Build::Structure.call(weapon, store: @store)[1]
  rescue StandardError => e
    say "#{gid}: structure build failed (#{e.class}: #{e.message})"
    []
  end

  # The text without a page break, or nil when it has none.
  def strip(text)
    return nil if text.blank?

    fixed = text.sub(GLUED_FIELD, "")
    fixed = fixed.sub(PARAMETER_DEFAULT, '\1')
    fixed = fixed.sub(TRAILING_PIPES, "")
    fixed = fixed.strip
    return nil if fixed == text || fixed.empty? || fixed.include?("{{{")
    return nil unless fixed.scan("{{").size == fixed.scan("}}").size

    fixed
  end
end
