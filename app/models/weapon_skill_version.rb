# frozen_string_literal: true

# One tier of a weapon skill slot (base / FLB / ULB / Transcendence stage).
# The name and icon are canonical on the shared Skill catalog and read through
# #skill. The tier's own text lives here (description_en/_jp): Skill#description_*
# is shared by name across weapons and tiers, so it can't hold per-tier text. The
# version also carries the tier requirement and parser-derived scaling/condition attributes.
class WeaponSkillVersion < ApplicationRecord
  include CurationExportTracking

  self.curation_stamp_column = :overrides_edited_at

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

  delegate :name_en, :name_jp, to: :skill, allow_nil: true

  # The tier's own text, else the shared skill's (see WeaponSkills::VersionText).
  # The raw columns are read_attribute(:description_en/_jp).
  def description_en = WeaponSkills::VersionText.for(self, :en)
  def description_jp = WeaponSkills::VersionText.for(self, :jp)

  # Classification overrides are curation: reparse rewrites the derived skill_modifier/
  # skill_series/skill_size, never these. Resolution goes through resolved_* everywhere.
  # modifier_override "none" pins "no family": canonical fallback must not fire
  # (Rhomphaia's tail-word collisions were curated by nulling the modifier, which
  # reparse re-derived — the sentinel survives).
  def resolved_modifier
    return nil if modifier_override == "none"

    modifier_override.presence || skill_modifier
  end

  def resolved_series   = series_override.presence || skill_series
  def resolved_size     = size_override.presence || skill_size

  # #resolved_modifier as SQL, for queries that group or filter versions by family.
  RESOLVED_MODIFIER_SQL = <<~SQL.squish
    (CASE WHEN weapon_skill_versions.modifier_override = 'none' THEN NULL
     ELSE COALESCE(NULLIF(weapon_skill_versions.modifier_override, ''), weapon_skill_versions.skill_modifier) END)
  SQL

  # Versions whose resolved family is modifier.
  scope :in_family, ->(modifier) { where("#{RESOLVED_MODIFIER_SQL} = ?", modifier) }
  # Versions that resolve to some family.
  scope :with_family, -> { where("COALESCE(#{RESOLVED_MODIFIER_SQL}, '') <> ''") }

  # Read-time precedence, the same for data and effects (overlay-v2.md "Precedence at read
  # time"). Per boost_type, the first of these that has rows wins:
  #   1. curated version-linked rows (manually_edited_at set: the overlay or an admin edit);
  #   2. suppressed (suppressed_boosts lists the boost type): nothing;
  #   3. the family default (the canonical rows of the resolved modifier);
  #   4. generated version-linked rows (the build's output).
  # Data and effects resolve separately: a boost type may have rows in both tables
  # (Sephira Manus's DA curve plus its Arcarum effect), and both apply.
  # suppressed_boosts "*" keeps its build meaning (no extraction): it hides generated rows
  # only, never the family or a curated row.

  # SL-scaled data for this version. Fully unmodeled skills resolve entirely through
  # version-linked rows; composite skills mix (Restraint's DA is the family's, its
  # Critical half a linked row).
  def weapon_skill_data
    family = WeaponSkillDatum.for_skill(modifier: resolved_modifier, series: resolved_series,
                                        size: resolved_size).to_a
    resolve_by_boost_type(family, linked_rows(WeaponSkillDatum))
  end

  # Conditional/fixed grid mechanics for this version (Pact, Charge, Voltage, …), as a
  # relation. A skill-specific value the family row can't express (Voltage II's 8% per
  # copy against Voltage's 4%) is a curated row, so it beats the family.
  def weapon_skill_effects
    family = resolved_modifier.present? ? WeaponSkillEffect.for_skill(modifier: resolved_modifier).base_effects.to_a : []
    WeaponSkillEffect.where(id: resolve_by_boost_type(family, linked_rows(WeaponSkillEffect)).map(&:id))
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

  # An unsaved version has no linked rows (where(weapon_skill_version_id: nil) would be
  # every canonical row).
  def linked_rows(model) = id ? model.where(weapon_skill_version_id: id).to_a : []

  # family: the canonical rows; linked: this version's rows. → family, curated, generated.
  def resolve_by_boost_type(family, linked)
    curated, generated = linked.partition(&:manually_edited_at)
    suppressed = Array(suppressed_boosts).to_set
    curated_types = curated.to_set(&:boost_type)
    family_types = family.to_set(&:boost_type)

    kept_family = family.reject { |row| curated_types.include?(row.boost_type) || suppressed.include?(row.boost_type) }
    kept_generated = generated.reject do |row|
      boost = row.boost_type
      curated_types.include?(boost) || suppressed.include?(boost) || suppressed.include?("*") ||
        family_types.include?(boost)
    end
    kept_family + curated + kept_generated
  end

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
