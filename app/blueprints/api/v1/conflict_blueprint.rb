# frozen_string_literal: true

module Api
  module V1
    class ConflictBlueprint < ApiBlueprint
      field :position do
        options[:incoming_position]
      end

      view :characters do
        field :conflicts do
          GridCharacterBlueprint.render_as_hash(options[:conflict_characters])
        end

        field :incoming do
          GridCharacterBlueprint.render_as_hash(options[:incoming_character])
        end
      end

      view :weapons do
        field :conflicts do
          GridWeaponBlueprint.render_as_hash(options[:conflict_weapons])
        end

        field :incoming do
          GridWeaponBlueprint.render_as_hash(options[:incoming_weapon])
        end
      end
    end
  end
end
