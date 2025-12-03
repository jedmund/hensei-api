class CollectionWeapon < ApplicationRecord
  belongs_to :user
  belongs_to :weapon
  belongs_to :awakening, optional: true

  belongs_to :weapon_key1, class_name: 'WeaponKey', optional: true
  belongs_to :weapon_key2, class_name: 'WeaponKey', optional: true
  belongs_to :weapon_key3, class_name: 'WeaponKey', optional: true
  belongs_to :weapon_key4, class_name: 'WeaponKey', optional: true

  # Set defaults before validation so database defaults don't cause validation failures
  attribute :awakening_level, :integer, default: 1

  validates :uncap_level, inclusion: { in: 0..5 }
  validates :transcendence_step, inclusion: { in: 0..10 }
  validates :awakening_level, inclusion: { in: 1..10 }

  validate :validate_weapon_keys
  validate :validate_ax_skills
  validate :validate_element_change
  validate :validate_awakening_compatibility
  validate :validate_awakening_level
  validate :validate_transcendence_requirements

  scope :by_weapon, ->(weapon_id) { where(weapon_id: weapon_id) }
  scope :by_series, ->(series_id) { joins(:weapon).where(weapons: { weapon_series_id: series_id }) }
  scope :with_keys, -> { where.not(weapon_key1_id: nil) }
  scope :with_ax, -> { where.not(ax_modifier1: nil) }
  scope :by_element, ->(element) { joins(:weapon).where(weapons: { element: element }) }
  scope :by_rarity, ->(rarity) { joins(:weapon).where(weapons: { rarity: rarity }) }
  scope :transcended, -> { where('transcendence_step > 0') }
  scope :with_awakening, -> { where.not(awakening_id: nil) }

  def blueprint
    Api::V1::CollectionWeaponBlueprint
  end

  def weapon_keys
    [weapon_key1, weapon_key2, weapon_key3, weapon_key4].compact
  end

  private

  def validate_weapon_keys
    return unless weapon.present?

    # Validate weapon_key4 is only on Opus/Draconic weapons
    if weapon_key4.present? && !weapon.opus_or_draconic?
      errors.add(:weapon_key4, "can only be set on Opus or Draconic weapons")
    end

    weapon_keys.each do |key|
      unless weapon.compatible_with_key?(key)
        errors.add(:weapon_keys, "#{key.name_en} is not compatible with this weapon")
      end
    end

    # Check for duplicate keys
    key_ids = [weapon_key1_id, weapon_key2_id, weapon_key3_id, weapon_key4_id].compact
    if key_ids.length != key_ids.uniq.length
      errors.add(:weapon_keys, "cannot have duplicate keys")
    end
  end

  def validate_ax_skills
    # Check for incomplete AX skills regardless of weapon.ax
    if (ax_modifier1.present? && ax_strength1.blank?) ||
       (ax_modifier1.blank? && ax_strength1.present?)
      errors.add(:base, "AX skill 1 must have both modifier and strength")
    end

    if (ax_modifier2.present? && ax_strength2.blank?) ||
       (ax_modifier2.blank? && ax_strength2.present?)
      errors.add(:base, "AX skill 2 must have both modifier and strength")
    end
  end

  def validate_element_change
    return unless element.present? && weapon.present?

    unless Weapon.element_changeable?(weapon)
      errors.add(:element, "can only be set on element-changeable weapons")
    end
  end

  def validate_awakening_compatibility
    return unless awakening.present?

    unless awakening.object_type == 'Weapon'
      errors.add(:awakening, "must be a weapon awakening")
    end
  end

  def validate_awakening_level
    if awakening_level.present? && awakening_level > 1 && awakening_id.blank?
      errors.add(:awakening_level, "cannot be set without an awakening")
    end
  end

  def validate_transcendence_requirements
    return unless transcendence_step.present? && transcendence_step > 0

    if uncap_level < 5
      errors.add(:transcendence_step, "requires uncap level 5 (current: #{uncap_level})")
    end

    # Some weapons might not support transcendence
    if weapon.present? && !weapon.transcendence
      errors.add(:transcendence_step, "not available for this weapon") if transcendence_step > 0
    end
  end
end