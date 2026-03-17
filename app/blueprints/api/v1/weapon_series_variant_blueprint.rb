# frozen_string_literal: true

module Api
  module V1
    class WeaponSeriesVariantBlueprint < ApiBlueprint
      fields :name, :has_weapon_keys, :has_awakening, :num_weapon_keys,
             :augment_type, :element_changeable, :extra
    end
  end
end
