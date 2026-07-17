# frozen_string_literal: true

# The Rose Crystal series has two shared profiles. The descriptions identify the
# profile, while the series page and one in-game SL10 capture from each profile
# establish their values. Pin every member so the size-only description fallback
# cannot substitute an unrelated, stronger curve on the next scoped extraction.
class CurateRoseCrystalSeriesValues < ActiveRecord::Migration[8.0]
  EXPECTED_WEAPON_COUNT = 8
  EXPECTED_PROFILE_COUNTS = { brier: 4, thorns: 4 }.freeze
  PROVENANCE = "wiki_series_panel_capture"
  REDUCTION_ELEMENTS = %w[fire water earth wind].freeze

  BRIER_PATTERN = /\AMedium boost to .+ allies' ATK and max HP\z/i
  THORNS_PATTERN = /\ABig boost to .+ allies' ATK\z/i
  BUD_PATTERN = /\ALessen (?<element>fire|water|earth|wind) DMG taken for .+ allies\z/i
  BARRIER_PATTERN = /\ALessen (?<element>fire|water|earth|wind) DMG for all allies\z/i

  PROFILES = {
    brier: {
      size: "medium",
      data: { "atk" => [3.0, 12.0], "hp" => [3.0, 12.0] },
      reduction_pattern: BUD_PATTERN,
      reduction_value: 20.0,
      applies_to: "element_allies"
    },
    thorns: {
      size: "big",
      data: { "atk" => [6.0, 15.0] },
      reduction_pattern: BARRIER_PATTERN,
      reduction_value: 10.0,
      applies_to: "all_allies"
    }
  }.freeze

  def up
    upsert_panel_metadata
    profiles = rose_weapons.map { |weapon| classify(weapon) }
    counts = profiles.map { |profile| profile.fetch(:type) }.tally
    unless counts == EXPECTED_PROFILE_COUNTS
      raise "Unexpected Rose Crystal profile counts: #{counts.inspect}"
    end

    profiles.each do |profile|
      attrs = PROFILES.fetch(profile.fetch(:type))
      attrs.fetch(:data).each do |boost_type, anchors|
        upsert_datum(profile.fetch(:first_version), boost_type, anchors)
      end
      upsert_reduction(profile.fetch(:second_version), profile.fetch(:reduced_element), attrs)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "the replaced Rose Crystal values came from an incorrect family-blind fallback"
  end

  private

  def rose_weapons
    weapons = Weapon.joins(:weapon_series).where(weapon_series: { slug: "rose" }).to_a
    return weapons if weapons.size == EXPECTED_WEAPON_COUNT

    raise "Expected #{EXPECTED_WEAPON_COUNT} Rose Crystal weapons, found #{weapons.size}"
  end

  def upsert_panel_metadata
    REDUCTION_ELEMENTS.each do |element|
      boost = WeaponSkillBoostType.find_or_initialize_by(key: "#{element}_reduc")
      boost.update!(
        name_en: "#{element.capitalize} Reduc.",
        category: "defensive",
        grid_cap: nil,
        cap_is_flat: false,
        stacking_rule: "additive",
        display_cap: 30,
        amplifiable: false,
        notes: "Reduce #{element} damage taken."
      )
    end

    GridDamage::PanelPresenter::LINES.each_with_index do |(key, series, label, slug, group), position|
      PanelLine.find_or_initialize_by(boost_type: key, series: series).update!(
        label_en: label, slug: slug, group_name: group, position: position
      )
    end
  end

  def classify(weapon)
    raise "Unexpected max skill level for #{weapon.name_en}" unless weapon.max_skill_level == 10

    first = version_for(weapon, 0)
    second = version_for(weapon, 1)
    type = profile_type(first.description_en)
    attrs = PROFILES.fetch(type)
    unless first.resolved_series == "ex" && first.resolved_size == attrs.fetch(:size)
      raise "Unexpected first-skill metadata for #{weapon.name_en}"
    end

    reduction_match = second.description_en.to_s.match(attrs.fetch(:reduction_pattern))
    raise "Unexpected reduction skill for #{weapon.name_en}: #{second.description_en.inspect}" unless reduction_match

    {
      type: type,
      first_version: first,
      second_version: second,
      reduced_element: reduction_match[:element].downcase
    }
  end

  def profile_type(description)
    case description.to_s
    when BRIER_PATTERN then :brier
    when THORNS_PATTERN then :thorns
    else raise "Unexpected Rose Crystal attack skill: #{description.inspect}"
    end
  end

  def version_for(weapon, position)
    weapon.weapon_skills.find_by!(position: position).weapon_skill_versions.find_by!(ordinal: 0)
  end

  def upsert_datum(version, boost_type, anchors)
    datum = WeaponSkillDatum.find_or_initialize_by(
      weapon_skill_version_id: version.id,
      boost_type: boost_type
    )
    datum.assign_attributes(
      modifier: version.skill.name_en,
      series: "ex",
      size: version.resolved_size,
      formula_type: "flat",
      sl1: anchors[0],
      sl10: anchors[1],
      sl15: nil,
      sl20: nil,
      sl25: nil,
      coefficient: nil,
      max_value: nil,
      aura_boostable: false,
      manually_edited_at: Time.current,
      provenance: PROVENANCE
    )
    datum.save!
  end

  def upsert_reduction(version, reduced_element, attrs)
    effect = WeaponSkillEffect.find_or_initialize_by(
      weapon_skill_version_id: version.id,
      boost_type: "elem_reduc",
      scaling_kind: "static"
    )
    effect.assign_attributes(
      modifier: version.skill.name_en,
      series: "ex",
      value: attrs.fetch(:reduction_value),
      value_unit: "percent",
      condition: { "reduced_element" => reduced_element },
      aura_boostable: false,
      seraphic_affected: false,
      stacking: "additive",
      applies_to: attrs.fetch(:applies_to),
      battle_interaction: false,
      notes: "Reduces #{reduced_element} damage; Rose Crystal #{attrs.fetch(:reduction_value).to_i}% profile.",
      manually_edited_at: Time.current,
      provenance: PROVENANCE
    )
    effect.save!
  end
end
