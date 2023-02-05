# frozen_string_literal: true

module Api
  module V1
    class GridCharactersController < Api::V1::ApiController
      attr_reader :party, :incoming_character, :current_characters

      before_action :find_party, only: :create
      before_action :set, only: %i[update destroy]
      before_action :authorize, only: %i[create update destroy]
      before_action :find_incoming_character, only: :create
      before_action :find_current_characters, only: :create

      def create
        if !conflict_characters.nil? && conflict_characters.length.positive?
          # Render a template with the conflicting and incoming characters,
          # as well as the selected position, so the user can be presented with
          # a decision.

          # Up to 3 characters can be removed at the same time
          conflict_view = render_conflict_view(conflict_characters, incoming_character, character_params[:position])
          render json: conflict_view
        else
          # Destroy the grid character in the position if it is already filled
          if GridCharacter.where(party_id: party.id, position: character_params[:position]).exists?
            character = GridCharacter.where(party_id: party.id, position: character_params[:position]).limit(1)[0]
            character.destroy
          end

          # Then, create a new grid character
          character = GridCharacter.create!(character_params.merge(party_id: party.id,
                                                                   character_id: incoming_character.id))

          if character.save!
            grid_character_view = render_grid_character_view(character)
            render json: grid_character_view, status: :created
          end
        end
      end

      def update
        mastery = {}
        %i[ring1 ring2 ring3 ring4 earring awakening].each do |key|
          value = character_params.to_h[key]
          mastery[key] = value unless value.nil?
        end

        @character.attributes = character_params.merge(mastery)

        return render json: GridCharacterBlueprint.render(@character, view: :full) if @character.save

        render_validation_error_response(@character)
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
        character.transcendence_step = character_params[:transcendence_step]
        return unless character.save!

        render json: GridCharacterBlueprint.render(character, view: :nested, root: :grid_character)
      end

      # TODO: Implement removing characters
      def destroy
        render_unauthorized_response if @character.party.user != current_user
        return render json: GridCharacterBlueprint.render(@character, view: :destroyed) if @character.destroy
      end

      private

      def conflict_characters
        @conflict_characters ||= find_conflict_characters(incoming_character)
      end

      def find_conflict_characters(incoming_character)
        # Check all character ids on incoming character against current characters
        conflict_ids = (current_characters & incoming_character.character_id)

        return unless conflict_ids.length.positive?

        # Find conflicting character ids in party characters
        party.characters.filter do |c|
          c if (conflict_ids & c.character.character_id).length.positive?
        end.flatten
      end

      def find_current_characters
        # Make a list of all character IDs
        @current_characters = party.characters.map do |c|
          Character.find(c.character.id).character_id
        end.flatten
      end

      def set
        @character = GridCharacter.find(params[:id])
      end

      def find_incoming_character
        @incoming_character = Character.find(character_params[:character_id])
      end

      def find_party
        @party = Party.find(character_params[:party_id])
        render_unauthorized_response if current_user && (party.user != current_user)
      end

      def authorize
        # Create
        unauthorized_create = @party && (@party.user != current_user || @party.edit_key != edit_key)
        unauthorized_update = @character && @character.party && (@character.party.user != current_user || @character.party.edit_key != edit_key)

        render_unauthorized_response if unauthorized_create || unauthorized_update
      end

      # Specify whitelisted properties that can be modified.
      def character_params
        params.require(:character).permit(:id, :party_id, :character_id, :position,
                                          :uncap_level, :transcendence_step, :perpetuity,
                                          ring1: %i[modifier strength], ring2: %i[modifier strength],
                                          ring3: %i[modifier strength], ring4: %i[modifier strength],
                                          earring: %i[modifier strength], awakening: %i[type level])
      end

      def resolve_params
        params.require(:resolve).permit(:position, :incoming, conflicting: [])
      end

      def render_conflict_view(conflict_characters, incoming_character, incoming_position)
        ConflictBlueprint.render(nil,
                                 view: :characters,
                                 conflict_characters: conflict_characters,
                                 incoming_character: incoming_character,
                                 incoming_position: incoming_position)
      end

      def render_grid_character_view(grid_character)
        GridCharacterBlueprint.render(grid_character, view: :nested)
      end
    end
  end
end
