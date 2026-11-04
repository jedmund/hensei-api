# frozen_string_literal: true

module Api
  module V1
    # Characters in a user's collection. A user owns at most one of each character.
    class CollectionCharactersController < CollectionItemsController
      ACCESSORY = %i[modifier strength].freeze

      collection_item :character,
                      catalog: Character,
                      blueprint: Api::V1::CollectionCharacterBlueprint,
                      catalog_blueprint: CharacterBlueprint,
                      catalog_view: :dates,
                      import_service: CharacterImportService,
                      permitted: [
                        :character_id, :uncap_level, :transcendence_step, :perpetuity,
                        :awakening_id, :awakening_level,
                        { ring1: ACCESSORY, ring2: ACCESSORY, ring3: ACCESSORY, ring4: ACCESSORY, earring: ACCESSORY }
                      ],
                      owned_includes: [{ character: :character_series_records }, :awakening],
                      unowned_includes: :character_series_records,
                      owned_filters: { race: :by_race, proficiency: :by_proficiency, gender: :by_gender },
                      # Characters have two race and two proficiency columns; either may match.
                      unowned_filters: {
                        race: %i[race1 race2],
                        proficiency: %i[proficiency1 proficiency2],
                        gender: :gender,
                        series: CollectionItemQuery::Filter.scope(:by_series)
                      },
                      proficiency_column: :proficiency1,
                      unique_per_user: true

      private

      def render_create_error(item)
        raise CollectionErrors::DuplicateCharacter, item.character_id if duplicate_character?(item)

        super
      end

      def duplicate_character?(item)
        item.errors[:character_id].any? { |e| e.include?('already exists') }
      end
    end
  end
end
