# frozen_string_literal: true

# Shared capability resolution for models that reference a weapon (CollectionWeapon, GridWeapon).
# Resolves each capability flag through the weapon's variant first, falling back to the series.
module WeaponCapabilityResolution
  extend ActiveSupport::Concern

  private

  def weapon_has_weapon_keys?
    weapon&.effective_has_weapon_keys || false
  end

  def weapon_has_awakening?
    weapon&.effective_has_awakening || false
  end

  def weapon_element_changeable?
    weapon&.effective_element_changeable || false
  end

  def weapon_augment_type
    weapon&.effective_augment_type || 'no_augment'
  end
end
