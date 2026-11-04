# frozen_string_literal: true

##
# The weapon-skill family list: one row per modifier found in the canonical
# weapon_skill_data and weapon_skill_effects rows or resolved by a version,
# with what it covers and how much uses it, filtered and sorted by modifier.
#
# @example
#   WeaponSkillFamilyIndex.new(query: 'might', boost_type: 'atk').call
#   # => [{ modifier: 'Might', display_name: {...}, boost_types: [...], counts: {...}, ... }]
class WeaponSkillFamilyIndex
  # @param query [String, nil] downcased text to find in the modifier or display names
  # @param series [String, nil]
  # @param size [String, nil]
  # @param boost_type [String, nil]
  # @param has_effects [Boolean] only families with canonical effect rows
  # @param manually_edited [Boolean] only families with an edited row
  def initialize(query: nil, series: nil, size: nil, boost_type: nil, has_effects: false, manually_edited: false)
    @query = query
    @series = series
    @size = size
    @boost_type = boost_type
    @has_effects = has_effects
    @manually_edited = manually_edited
  end

  # @return [Array<Hash>] sorted by modifier, ignoring case
  def call
    filter(families).sort_by { |f| f[:modifier].downcase }
  end

  private

  def families
    data_rows = WeaponSkillDatum.all.to_a
    effect_rows = WeaponSkillEffect.where(weapon_skill_version_id: nil).to_a

    modifiers = (data_rows.map(&:modifier) + effect_rows.map(&:modifier) + version_stats.keys).compact.uniq
    modifiers.map do |mod|
      family(mod, data_rows.select { |r| r.modifier == mod }, effect_rows.select { |r| r.modifier == mod })
    end
  end

  def family(mod, data, effects)
    stats = version_stats[mod] || { versions: 0, weapons: 0 }
    {
      modifier: mod,
      display_name: family_display_names[mod],
      icon_stems: family_icon_stems[mod] || [],
      boost_types: (data.map(&:boost_type) + effects.map(&:boost_type)).uniq.sort,
      series: (data.filter_map(&:series) + effects.filter_map(&:series)).uniq.sort,
      sizes: data.filter_map(&:size).uniq.sort,
      formula_types: data.filter_map(&:formula_type).uniq.sort,
      counts: { data_rows: data.size, effect_rows: effects.size,
                versions: stats[:versions], weapons: stats[:weapons] },
      manually_edited: (data + effects).any?(&:manually_edited_at)
    }
  end

  # Versions and distinct weapons per resolved family
  def version_stats
    @version_stats ||= version_stats_by_family
  end

  def version_stats_by_family
    family = Arel.sql(WeaponSkillVersion::RESOLVED_MODIFIER_SQL)
    WeaponSkillVersion.joins(:weapon_skill)
                      .with_family
                      .group(family)
                      .pluck(family,
                             Arel.sql('COUNT(*)'),
                             Arel.sql('COUNT(DISTINCT weapon_skills.weapon_granblue_id)'))
                      .to_h { |mod, versions, weapons| [mod, { versions: versions, weapons: weapons }] }
  end

  # Linked skill name per family, but only when every version agrees on one —
  # names like "Tsunami's Aegis" / "Mountain's Aegis" are per-weapon flavor
  # text for the same mechanical family, so a family spanning several of
  # them has no single true name (falls back to the modifier instead).
  def family_display_names
    @family_display_names ||= display_names_by_family
  end

  def display_names_by_family
    family = Arel.sql(WeaponSkillVersion::RESOLVED_MODIFIER_SQL)
    rows = WeaponSkillVersion.joins(:skill)
                             .with_family
                             .group(family, 'skills.name_en', 'skills.name_jp')
                             .pluck(family, 'skills.name_en', 'skills.name_jp')
    rows.group_by { |mod, _, _| mod }.each_with_object({}) do |(mod, entries), out|
      next unless entries.size == 1

      (_, en, ja) = entries.first
      out[mod] = { en: en, ja: ja }
    end
  end

  # All distinct resolvable icon stems per family — a family can carry more than
  # one when versions resolve to different element/type art (e.g. Aegis's
  # per-element icons), and the frontend cycles through them for those.
  def family_icon_stems
    @family_icon_stems ||= icon_stems_by_family
  end

  def icon_stems_by_family
    versions = WeaponSkillVersion.joins(weapon_skill: :weapon)
                                 .with_family
                                 .includes(weapon_skill: :weapon)
    versions.each_with_object(Hash.new { |h, k| h[k] = [] }) do |v, out|
      stem = v.icon_stem
      next if stem.blank?

      family = v.resolved_modifier
      out[family] << stem unless out[family].include?(stem)
    end
  end

  def filter(families)
    checks = [
      (->(f) { matches_query?(f) } if @query),
      (->(f) { f[:series].include?(@series) } if @series),
      (->(f) { f[:sizes].include?(@size) } if @size),
      (->(f) { f[:boost_types].include?(@boost_type) } if @boost_type),
      (->(f) { f[:counts][:effect_rows].positive? } if @has_effects),
      (->(f) { f[:manually_edited] } if @manually_edited)
    ].compact
    families.select { |f| checks.all? { |check| check.call(f) } }
  end

  def matches_query?(family)
    family[:modifier].downcase.include?(@query) ||
      family[:display_name]&.values&.any? { |n| n&.downcase&.include?(@query) }
  end
end
