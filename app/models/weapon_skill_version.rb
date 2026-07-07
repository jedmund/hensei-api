# frozen_string_literal: true

# One tier of a weapon skill slot (base / FLB / ULB / Transcendence stage).
# Content (name/description) is canonical on the shared Skill catalog and read
# through #skill — never duplicated here. The version carries only the
# tier requirement and parser-derived scaling/condition attributes.
class WeaponSkillVersion < ApplicationRecord
  belongs_to :weapon_skill, inverse_of: :weapon_skill_versions
  belongs_to :skill

  # Which summon auras boost this skill (see WeaponSkill history for details).
  enum :skill_series, {
    normal: 'normal',
    omega: 'omega',
    ex: 'ex',
    odious: 'odious'
  }

  enum :skill_size, {
    small: 'small',
    medium: 'medium',
    big: 'big',
    big_ii: 'big_ii',
    massive: 'massive',
    unworldly: 'unworldly',
    ancestral: 'ancestral'
  }

  VALID_MODIFIERS = Granblue::Parsers::WeaponSkillParser::KNOWN_MODIFIERS

  # skill presence is enforced by the required belongs_to :skill above.
  validates :ordinal, presence: true,
                      numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :min_uncap, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :transcendence_stage, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :skill_modifier, inclusion: { in: VALID_MODIFIERS }, allow_nil: true

  delegate :name_en, :name_jp, :description_en, :description_jp, to: :skill, allow_nil: true

  # SL-scaled data for this version: the canonical modifier/series/size rows PLUS any
  # description-derived per-version rows that fill boost_types the canonical data is missing
  # (composite skills — e.g. Restraint's DA is canonical, its Critical half is version-linked).
  # Fully unmodeled skills resolve entirely through the version-linked rows.
  def weapon_skill_data
    canonical = WeaponSkillDatum.for_skill(modifier: skill_modifier, series: skill_series, size: skill_size).to_a
    linked = WeaponSkillDatum.where(weapon_skill_version_id: id).to_a
    return linked if canonical.empty?

    have = canonical.to_set(&:boost_type)
    canonical + linked.reject { |d| have.include?(d.boost_type) }
  end

  # Conditional/fixed grid mechanics for this version: description-derived per-version effects
  # plus the canonical modifier-keyed effects (Pact, Charge, …). A version-linked row is
  # skill-specific curation (Axe Voltage II's 8%/axe), so per boost_type it REPLACES the
  # family fallback (Voltage's 4%) instead of stacking with it — the mirror of
  # weapon_skill_data, where the canonical curve wins and linked rows only fill gaps.
  def weapon_skill_effects
    linked = WeaponSkillEffect.where(weapon_skill_version_id: id)
    return linked if skill_modifier.blank?

    have = linked.pluck(:boost_type).to_set
    canonical_ids = WeaponSkillEffect.for_skill(modifier: skill_modifier).base_effects
                                     .reject { |e| have.include?(e.boost_type) }.map(&:id)
    WeaponSkillEffect.where(id: linked.ids + canonical_ids)
  end

  # Normalized icon stem using OUR INTERNAL element numbering — the name files
  # are stored under and the frontend recreates (e.g. "skill_atk_4_4"). Nil when
  # the wiki icon is missing or can't be resolved. See WeaponSkillIconDownloader.
  def icon_stem
    resolved_icon_stem(internal: true)
  end

  # Same stem but using GRANBLUE element numbering — the name on the game CDN we
  # download from. Differs from #icon_stem only for element-wildcard icons.
  def icon_source_stem
    resolved_icon_stem(internal: false)
  end

  private

  # Cleans the wiki icon name to a CDN stem template, possibly still containing
  # the element wildcard "*": strips the {{WeaponSkillIcon|…}} wrapper and the
  # Ws_/ws_ prefix, lowercases, and drops the .png extension.
  def icon_template
    raw = icon.to_s.strip
    return nil if raw.blank?

    raw = Regexp.last_match(1).strip if raw =~ /\{\{WeaponSkillIcon\|([^}]+)\}\}/i
    # Strip the Ws_/ws_ prefix, tolerating the occasional "ws " typo on the wiki.
    stem = raw.downcase.strip.delete_suffix('.png').sub(/\Aws[ _]/, '')
    stem.presence
  end

  # Resolves the element wildcard against the parent weapon's element, in either
  # internal or Granblue numbering. Returns nil if anything is unresolved.
  def resolved_icon_stem(internal:)
    stem = icon_template
    return nil if stem.blank?

    if stem.include?('*')
      element = weapon_skill&.weapon&.element
      return nil unless element.is_a?(Integer) && element.between?(1, 6)

      number = internal ? element : (GranblueEnums::INTERNAL_TO_GBF_ELEMENT[element] || element)
      stem = stem.gsub('*', number.to_s)
    end

    stem.match?(/[{}*|]/) ? nil : stem
  end
end
