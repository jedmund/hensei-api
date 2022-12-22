# frozen_string_literal: true

module Api
  module V1
    class GridCharactersController < Api::V1::ApiController
      def create
        party = Party.find(character_params[:party_id])
        incoming_character = Character.find(character_params[:character_id])

        render_unauthorized_response if current_user && (party.user != current_user)

        current_characters = party.characters.map do |c|
          Character.find(c.character.id).character_id
        end.flatten

        # Check all character ids on incoming character against current characters
        conflict_ids = (current_characters & incoming_character.character_id)

        if conflict_ids.length.positive?
          # Find conflicting character ids in party characters
          conflict_characters = party.characters.filter do |c|
            c if (conflict_ids & c.character.character_id).length.positive?
          end.flatten

          # Render a template with the conflicting and incoming characters,
          # as well as the selected position, so the user can be presented with
          # a decision.

          # Up to 3 characters can be removed at the same time
          render json: ConflictBlueprint.render(nil, view: :characters,
                                                     conflict_characters: conflict_characters,
                                                     incoming_character: incoming_character,
                                                     incoming_position: character_params[:position])
        else
          # Replace the grid character in the position if it is already filled
          if GridCharacter.where(party_id: party.id, position: character_params[:position]).exists?
            character = GridCharacter.where(party_id: party.id, position: character_params[:position]).limit(1)[0]
            character.character_id = incoming_character.id

            # Otherwise, create a new grid character
          else
            character = GridCharacter.create!(character_params.merge(party_id: party.id,
                                                                     character_id: incoming_character.id))
          end

          render json: GridCharacterBlueprint.render(character, view: :nested), status: :created if character.save!
        end
      end

      def resolve
        incoming = Character.find(resolve_params[:incoming])
        conflicting = resolve_params[:conflicting].map { |id| GridCharacter.find(id) }
        party = conflicting.first.party

        # Destroy each conflicting character
        conflicting.each { |character| GridCharacter.destroy(character.id) }

        # Destroy the character at the desired position if it exists
        existing_character = GridCharacter.where(party: party.id, position: resolve_params[:position]).first
        GridCharacter.destroy(existing_character.id) if existing_character

        if incoming.special
          uncap_level = 3
          uncap_level = 5 if incoming.ulb
          uncap_level = 4 if incoming.flb
        else
          uncap_level = 4
          uncap_level = 6 if incoming.ulb
          uncap_level = 5 if incoming.flb
        end

        character = GridCharacter.create!(party_id: party.id, character_id: incoming.id,
                                          position: resolve_params[:position], uncap_level: uncap_level)
        render json: GridCharacterBlueprint.render(character, view: :nested), status: :created if character.save!
      end

      def update_uncap_level
        character = GridCharacter.find(character_params[:id])

        render_unauthorized_response if current_user && (character.party.user != current_user)

        character.uncap_level = character_params[:uncap_level]
        render json: GridCharacterBlueprint.render(character, view: :uncap) if character.save!
      end

      # TODO: Implement removing characters
      def destroy; end

      private

      # Specify whitelisted properties that can be modified.
      def character_params
        params.require(:character).permit(:id, :party_id, :character_id, :position, :uncap_level, :conflicting,
                                          :incoming)
      end

      def resolve_params
        params.require(:resolve).permit(:position, :incoming, conflicting: [])
      end
    end
  end
end
