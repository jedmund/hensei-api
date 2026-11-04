# frozen_string_literal: true

module Api
  module V1
    # Weapons in a user's collection. A user can own several copies of a weapon.
    class CollectionWeaponsController < CollectionItemsController
      include Concerns::CollectionInventorySync

      collection_item :weapon,
                      catalog: Weapon,
                      blueprint: Api::V1::CollectionWeaponBlueprint,
                      catalog_blueprint: WeaponBlueprint,
                      catalog_view: :grid,
                      import_service: WeaponImportService,
                      permitted: %i[
                        weapon_id uncap_level transcendence_step
                        weapon_key1_id weapon_key2_id weapon_key3_id weapon_key4_id
                        awakening_id awakening_level
                        ax_modifier1_id ax_strength1 ax_modifier2_id ax_strength2
                        befoulment_modifier_id befoulment_strength befoulment_permeation exorcism_level skill_level
                        element
                      ],
                      owned_includes: [
                        { weapon: %i[weapon_series weapon_series_variant] }, :awakening,
                        :weapon_key1, :weapon_key2, :weapon_key3, :weapon_key4,
                        :ax_modifier1, :ax_modifier2, :befoulment_modifier,
                        { collection_weapon_bullets: :bullet }
                      ],
                      unowned_includes: [
                        :weapon_series, :weapon_series_variant,
                        { recruited_character: :character_series_records }
                      ],
                      owned_filters: {
                        weapon_id: CollectionItemQuery::Filter.exact(:by_weapon),
                        proficiency: :by_proficiency
                      },
                      unowned_filters: { proficiency: :proficiency, series: :weapon_series_id },
                      proficiency_column: :proficiency

      private

      # Clears an imported skill level when the uncap changes without a new one.
      def assign_item_attributes(item, attrs)
        item.assign_with_skill_level(attrs)
      end
    end
  end
end
