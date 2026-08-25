# frozen_string_literal: true

# Shared validation for the two AX slots stored on collection and grid weapons.
# Pools and ranges come from WeaponStatModifier so the same wiki-backed metadata
# drives both the API choices and persisted-value validation.
module AxSkillValidation
  extend ActiveSupport::Concern

  included do
    validate :validate_ax_skills
  end

  private

  def validate_ax_skills
    validate_ax_pair(1)
    validate_ax_pair(2)
    return unless ax_values_present?

    unless weapon_augment_type == "ax"
      errors.add(:base, "AX skills are not available for this weapon")
      return
    end

    validate_ax_category(ax_modifier1, :ax_modifier1)
    validate_ax_category(ax_modifier2, :ax_modifier2)

    profile = weapon.effective_ax_type
    if ax_modifier1.blank?
      validate_ax_secondary(profile)
      return
    end
    return unless ax_modifier1.category == "ax"

    validate_ax_primary(profile)
    validate_ax_secondary(profile)
    validate_ax_strength(ax_modifier1, ax_strength1, :ax_strength1, secondary: false)
    validate_ax_strength(ax_modifier2, ax_strength2, :ax_strength2, secondary: true)
  end

  def validate_ax_pair(slot)
    modifier = public_send(:"ax_modifier#{slot}")
    strength = public_send(:"ax_strength#{slot}")
    return if modifier.present? == strength.present?

    errors.add(:base, "AX skill #{slot} must have both modifier and strength")
  end

  def ax_values_present?
    ax_modifier1.present? || ax_strength1.present? || ax_modifier2.present? || ax_strength2.present?
  end

  def validate_ax_category(modifier, field)
    return if modifier.blank? || modifier.category == "ax"

    errors.add(field, "must be an AX skill modifier")
  end

  def validate_ax_primary(profile)
    return if ax_modifier1.blank?

    allowed_groups = profile == "utility" ? %w[utility] : %w[primary]
    allowed_groups << "utility" if profile == "primal"
    return if allowed_groups.include?(ax_modifier1.ax_group)

    errors.add(:ax_modifier1, "is not available for this weapon's AX profile")
  end

  def validate_ax_secondary(profile)
    return if ax_modifier2.blank?

    if ax_modifier1.blank?
      errors.add(:ax_modifier2, "requires AX skill 1")
      return
    end

    if ax_modifier1.ax_group == "utility" || profile == "utility"
      errors.add(:ax_modifier2, "is not available with a utility AX skill")
      return
    end

    pool_name = profile == "xeno" ? "xeno" : "standard"
    allowed_slugs = Array(ax_modifier1.ax_secondaries.to_h[pool_name])
    return if allowed_slugs.include?(ax_modifier2.slug)

    errors.add(:ax_modifier2, "is not available for #{ax_modifier1.name_en}")
  end

  def validate_ax_strength(modifier, strength, field, secondary:)
    return if modifier.blank? || strength.blank? || modifier.category != "ax"

    minimum = secondary ? modifier.secondary_min : modifier.base_min
    maximum = secondary ? modifier.secondary_max : modifier.base_max
    value = Float(strength, exception: false)
    return if value && minimum && maximum && value.between?(minimum.to_f, maximum.to_f)

    errors.add(field, "must be between #{minimum} and #{maximum}")
  end
end
