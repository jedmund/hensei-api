# frozen_string_literal: true

module Api
  module V1
    class ConflictBlueprint < Blueprinter::Base
      field :position, if: ->(_fn, _obj, options) { options.key?(:incoming_position) } do |_, options|
        options[:incoming_position]
      end

      view :characters do
        field :conflicts, if: ->(_fn, _obj, options) { options.key?(:conflict_characters) } do |_, options|
          GridCharacterBlueprint.render_as_hash(options[:conflict_characters], view: :nested)
        end

        field :incoming, if: ->(_fn, _obj, options) { options.key?(:incoming_character) } do |_, options|
          CharacterBlueprint.render_as_hash(options[:incoming_character])
        end
      end

      view :weapons do
        field :conflicts, if: ->(_fn, _obj, options) { options.key?(:conflict_weapon) } do |_, options|
          GridWeaponBlueprint.render_as_hash(options[:conflict_weapon], view: :nested)
        end

        field :incoming, if: ->(_fn, _obj, options) { options.key?(:incoming_weapon) } do |_, options|
          WeaponBlueprint.render_as_hash(options[:incoming_weapon])
        end
      end
    end
  end
end
