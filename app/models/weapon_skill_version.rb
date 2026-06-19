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

  # Standard-modifier skills scale with skill level via the lookup table.
  # Unique/fixed-effect skills (nil modifier) return nothing here.
  def weapon_skill_data
    WeaponSkillDatum.for_skill(modifier: skill_modifier, series: skill_series, size: skill_size)
  end

  # Conditional/fixed grid mechanics for this skill type (Pact, Charge, etc.),
  # keyed by modifier. Empty for unique/unrecognized skills.
  def weapon_skill_effects
    return WeaponSkillEffect.none if skill_modifier.blank?

    WeaponSkillEffect.for_skill(modifier: skill_modifier).base_effects
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
