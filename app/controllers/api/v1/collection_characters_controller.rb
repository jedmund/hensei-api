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
                      proficiency_column: :proficiency1,
                      permitted: [
                        :character_id, :uncap_level, :transcendence_step, :perpetuity,
                        :awakening_id, :awakening_level,
                        { ring1: ACCESSORY, ring2: ACCESSORY, ring3: ACCESSORY, ring4: ACCESSORY, earring: ACCESSORY }
                      ],
                      owned_includes: [{ character: :character_series_records }, :awakening],
                      unowned_includes: :character_series_records

      private

      def filter_owned_by_type(scope)
        scope = scope.by_race(array_param(:race)) if params[:race]
        scope = scope.by_proficiency(array_param(:proficiency)) if params[:proficiency]
        scope = scope.by_gender(array_param(:gender)) if params[:gender]
        scope
      end

      # Characters have two race and two proficiency columns; either may match.
      def filter_unowned_by_type(scope)
        scope = where_either(scope, :race1, :race2, array_param(:race)) if params[:race]
        scope = where_either(scope, :proficiency1, :proficiency2, array_param(:proficiency)) if params[:proficiency]
        scope = scope.where(gender: array_param(:gender)) if params[:gender]
        scope = scope.by_series(array_param(:series)) if params[:series]
        scope
      end

      def where_either(scope, first_column, second_column, values)
        scope.where(first_column => values).or(scope.where(second_column => values))
      end

      def render_create_error(item)
        raise CollectionErrors::DuplicateCharacter, item.character_id if duplicate_character?(item)

        super
      end

      def duplicate_character?(item)
        item.errors[:character_id].any? { |e| e.include?('already exists') }
      end

      # A batch skips characters the user already has.
      def batch_skip_reason(attrs)
        'already_exists' if current_user_items.exists?(character_id: attrs[:character_id])
      end

      def batch_meta(created:, skipped:, errors:)
        { created: created.size, skipped: skipped.size, skipped_items: skipped, errors: errors }
      end
    end
  end
end
