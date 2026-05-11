# frozen_string_literal: true

module Api
  module V1
    class SubstitutionsController < ApiController
      include PartyAuthorizationConcern

      DUPLICATE_ERROR = 'item is already a substitute for this slot'

      before_action :restrict_access
      before_action :set_party
      before_action :authorize_party!
      before_action :set_substitution, only: %i[update destroy]

      def create
        grid_type = substitution_params[:grid_type]
        grid_id = substitution_params[:grid_id]
        item_id = substitution_params[:item_id]

        grid_class = grid_class_for(grid_type)
        return render json: { error: "invalid grid_type: #{grid_type}" }, status: :unprocessable_entity unless grid_class

        grid_item = grid_class.where(party: @party).find_by(id: grid_id)
        return render_not_found_response('grid item') unless grid_item

        item_fk = item_foreign_key(grid_type)
        canonical = ITEM_CLASS_FOR_GRID[grid_type]&.find_by(id: item_id)
        unless canonical
          return render json: { error: "unknown item_id: #{item_id}" }, status: :unprocessable_entity
        end

        substitution = ApplicationRecord.transaction do
          substitute = grid_class.create!(
            party: @party,
            item_fk => item_id,
            position: grid_item.position,
            uncap_level: max_uncap_level_for(grid_type, canonical),
            is_substitute: true
          )

          Substitution.create!(
            grid_type: grid_type,
            grid_id: grid_id,
            substitute_grid_type: grid_type,
            substitute_grid_id: substitute.id,
            position: substitution_params[:position].presence&.to_i || next_position(grid_type, grid_id)
          )
        end

        @party.mark_updated!
        render json: SubstitutionBlueprint.render(substitution), status: :created
      rescue ActiveRecord::RecordNotUnique
        # Either two parallel requests added the same canonical item to this slot
        # (caught by index_*_unique_substitute on the grid_*items table) or two
        # parallel requests claimed the same position (caught by
        # index_substitutions_on_slot_position). The user-visible error is the
        # same in both cases.
        render json: { error: DUPLICATE_ERROR }, status: :unprocessable_entity
      rescue ActiveRecord::InvalidForeignKey
        render json: { error: "unknown item_id: #{params.dig(:substitution, :item_id)}" },
               status: :unprocessable_entity
      end

      def update
        if substitution_params[:position].blank?
          return render json: { error: 'position is required' }, status: :unprocessable_entity
        end

        ApplicationRecord.transaction do
          @substitution.update!(position: substitution_params[:position])
          @party.mark_updated!
        end

        render json: SubstitutionBlueprint.render(@substitution)
      rescue ActiveRecord::RecordNotUnique
        render json: { error: 'another substitution already occupies that position' },
               status: :unprocessable_entity
      end

      def destroy
        ApplicationRecord.transaction do
          substitute = @substitution.substitute_grid
          @substitution.destroy!
          substitute&.destroy!
          @party.mark_updated!
        end

        head :no_content
      end

      private

      def set_party
        party_id = params[:party_id] || params.dig(:substitution, :party_id)
        @party = Party.find(party_id)
      end

      def set_substitution
        @substitution = Substitution.find_by(id: params[:id])
        # Treat cross-party access as not-found to avoid leaking which ids exist.
        render_not_found_response('substitution') if @substitution.nil? || @substitution.grid&.party_id != @party.id
      end

      def substitution_params
        params.require(:substitution).permit(
          :grid_type, :grid_id, :item_id, :position, :party_id
        )
      end

      # Counts existing rows rather than MAX+1: after deletes, MAX+1 can produce
      # positions >= 10 while fewer than 10 rows exist (which would then fail
      # the numericality bound). The new unique index on (grid_type, grid_id,
      # position) prevents collisions if two creates race.
      def next_position(grid_type, grid_id)
        Substitution.where(grid_type: grid_type, grid_id: grid_id).count
      end

      GRID_TYPE_FOREIGN_KEYS = {
        'GridCharacter' => :character_id,
        'GridWeapon' => :weapon_id,
        'GridSummon' => :summon_id
      }.freeze

      ITEM_CLASS_FOR_GRID = {
        'GridCharacter' => Character,
        'GridWeapon' => Weapon,
        'GridSummon' => Summon
      }.freeze

      def item_foreign_key(grid_type)
        GRID_TYPE_FOREIGN_KEYS[grid_type]
      end

      # Allowlist gate so attacker-supplied grid_type can't load arbitrary classes.
      def grid_class_for(grid_type)
        return nil unless GRID_TYPE_FOREIGN_KEYS.key?(grid_type)

        grid_type.constantize
      end

      # Derives the natural max uncap for the canonical item so a substitute is
      # created at the same ceiling its real counterpart would use, rather than
      # the previous hardcoded 0.
      def max_uncap_level_for(grid_type, canonical)
        case grid_type
        when 'GridWeapon'
          weapon_max_uncap(canonical)
        when 'GridCharacter'
          character_max_uncap(canonical)
        when 'GridSummon'
          summon_max_uncap(canonical)
        end
      end

      def weapon_max_uncap(weapon)
        return 6 if weapon.transcendence
        return 5 if weapon.ulb
        return 4 if weapon.flb

        3
      end

      def character_max_uncap(character)
        if character.special
          return 5 if character.transcendence
          return 4 if character.flb

          3
        else
          return 6 if character.transcendence
          return 5 if character.flb

          4
        end
      end

      def summon_max_uncap(summon)
        return 6 if summon.transcendence
        return 5 if summon.ulb
        return 4 if summon.flb

        3
      end
    end
  end
end
