# frozen_string_literal: true

module Api
  module V1
    class WeaponSeriesBlueprint < ApiBlueprint
      field :name do |ws|
        {
          en: ws.name_en,
          ja: ws.name_jp
        }
      end

      fields :slug, :order, :extra, :element_changeable, :has_weapon_keys,
             :has_awakening, :augment_type, :num_weapon_keys

      view :full do
        field :weapon_count do |ws|
          ws.weapons.count
        end
      end
    end
  end
end
