# frozen_string_literal: true

module Api
  module V1
    ##
    # Controller handling API requests related to grid summons within a party.
    #
    # This controller provides endpoints for creating, updating, duplicating and quick-summoning
    # grid summons. Moving, swapping, uncapping, removing and collection sync come from
    # GridItemActions; the main and friend summon slots can't be moved into or swapped.
    #
    # @see Api::V1::ApiController for shared API behavior.
    class GridSummonsController < Api::V1::ApiController
      include IdResolvable
      include CollectionSourceConcern
      include PartyAuthorizationConcern
      include SubstituteGridPreloading
      include PartyFullLoading
      include GridItemActions

      attr_reader :party, :incoming_summon

      grid_item GridSummon, blueprint: GridSummonBlueprint, view: :nested,
                            positions: [-1, *0..6], restricted_positions: [-1, 6]

      before_action :find_grid_item, only: GridItemActions::ROW_ACTIONS + %i[update_quick_summon duplicate]
      before_action :find_party, only: GridItemActions::EDIT_ACTIONS + %i[update_quick_summon duplicate]
      before_action :find_incoming_summon, only: :create
      before_action :authorize_party_edit!, only: GridItemActions::EDIT_ACTIONS + %i[update_quick_summon duplicate]

      ##
      # Creates a new grid summon.
      #
      # This method builds a new grid summon using the permitted parameters merged
      # with the party and summon IDs. It ensures that the `uncap_level` is set to the
      # maximum allowed level if not provided. Depending on validation, it will either save
      # the summon, handle conflict resolution, or render a validation error response.
      #
      # @return [void]
      def create
        # Validate collection source constraint before proceeding
        if summon_params[:collection_summon_id].present?
          collection_item = CollectionSummon.find_by(id: summon_params[:collection_summon_id])
          return unless validate_collection_source!(@party, collection_item)
        end

        # Build a new grid summon using permitted parameters merged with party and summon IDs.
        # Set the uncap_level to the summon's maximum uncap level regardless of what the client sent.
        grid_summon = build_grid_summon.tap do |gs|
          gs.uncap_level = gs.summon.max_uncap_level
          gs.transcendence_step = gs.summon.max_transcendence_step
        end

        # If the grid summon is valid (i.e. it passes all validations), then save it normally.
        if grid_summon.valid?
          save_summon(grid_summon)
          # If it is invalid due to a conflict error, handle the conflict resolution flow.
        elsif conflict_error?(grid_summon)
          handle_conflict(grid_summon)
          # If there's some other kind of validation error, render the validation error response back to the client.
        else
          render_validation_error_response(grid_summon)
        end
      end

      ##
      # Updates an existing grid summon.
      #
      # Updates the grid summon attributes using permitted parameters. If the update is successful,
      # it renders the updated grid summon view; otherwise, it renders a validation error response.
      #
      # @return [void]
      def update
        if summon_params[:collection_summon_id].present?
          collection_item = CollectionSummon.find_by(id: summon_params[:collection_summon_id])
          return unless validate_collection_source!(@party, collection_item)
        end

        @grid_item.attributes = summon_params.merge(seal_state_params(:summon))

        ActiveRecord::Base.transaction do
          raise ActiveRecord::Rollback unless @grid_item.save

          apply_notes_sync!(summon_params)
        end

        if @grid_item.errors.empty?
          @grid_item.reload
          render json: GridSummonBlueprint.render(@grid_item, view: :nested, root: :grid_summon)
        else
          render_validation_error_response(@grid_item)
        end
      end

      ##
      # Updates the quick summon status for a grid summon.
      #
      # If the grid summon is in positions 4, 5, or 6, no update is performed.
      # Otherwise, it disables quick summon for all other summons in the party,
      # updates the current summon, and renders the updated list of summons.
      #
      # @return [void]
      def update_quick_summon
        return if [4, 5, 6].include?(@grid_item.position)

        quick_summons = @grid_item.party.summons.select(&:quick_summon)

        quick_summons.each do |summon|
          summon.update!(quick_summon: false)
        end

        @grid_item.update!(quick_summon: summon_params[:quick_summon])
        return unless @grid_item.persisted?

        @party.mark_updated!

        quick_summons -= [@grid_item]
        summons = [@grid_item] + quick_summons

        render json: GridSummonBlueprint.render(summons, view: :nested, root: :summons)
      end

      ##
      # Duplicates a GridSummon to a new position.
      #
      # Creates a copy of the grid summon at the specified target position.
      # Limited summons cannot be duplicated.
      # Collection links are not carried over to the duplicate.
      #
      # @return [void]
      def duplicate
        # Block limited summons
        if @grid_item.summon.limit
          return render_unprocessable_entity_response(
            Api::V1::GranblueError.new('Limited summons cannot be duplicated')
          )
        end

        position = duplicate_params[:position].to_i

        # Validate target position is a sub-summon slot (0-3)
        unless (0..3).cover?(position)
          return render_unprocessable_entity_response(
            Api::V1::InvalidPositionError.new("Invalid duplicate target position #{position}")
          )
        end

        # Check target position is empty
        if GridSummon.exists?(party_id: @party.id, position: position)
          return render_unprocessable_entity_response(
            Api::V1::PositionOccupiedError.new("Position #{position} is already occupied")
          )
        end

        new_summon = GridSummon.new(
          party_id: @party.id,
          summon_id: @grid_item.summon_id,
          position: position,
          uncap_level: @grid_item.uncap_level,
          transcendence_step: @grid_item.transcendence_step,
          collection_summon_id: nil,
          orphaned: false,
          main: false,
          friend: false,
          quick_summon: false
        )

        if new_summon.save
          @party.mark_updated!
          render json: GridSummonBlueprint.render(new_summon, view: :full, root: :grid_summon), status: :created
        else
          render_validation_error_response(new_summon)
        end
      end

      ##
      # Saves the provided grid summon.
      #
      # If an existing grid summon is found at the specified position for the party, it is replaced.
      # On successful save, renders the grid summon view with a created status.
      #
      # @param summon [GridSummon] The grid summon instance to be saved.
      # @return [void]
      def save_summon(summon)
        if (grid_summon = GridSummon.where(
          party_id: party.id,
          position: summon_params[:position]
        ).first)
          GridSummon.destroy(grid_summon.id)
        end

        return unless summon.save

        @party.mark_updated!
        summon.sync_from_collection! if summon.collection_summon_id.present?
        # Auto-join an existing notes sync group when this is a duplicate of a
        # summon already in a synced group.
        NotesSync.adopt_for_new_item!(summon)
        summon.reload
        output = render_replaced_view(summon)
        render json: output, status: :created
      end

      ##
      # Handles conflict resolution for a grid summon.
      #
      # If a conflict is detected and the conflicting summon matches the incoming summon,
      # the method updates the conflicting summon’s position with the new position.
      # On a successful update, renders the updated grid summon view.
      #
      # @param summon [GridSummon] The grid summon instance that encountered a conflict.
      # @return [void]
      def handle_conflict(summon)
        conflict_summon = summon.conflicts(party)
        return unless conflict_summon.summon.id == incoming_summon.id

        old_position = conflict_summon.position
        conflict_summon.position = summon_params[:position]

        return unless conflict_summon.save

        output = render_replaced_view(conflict_summon, old_position)
        render json: output
      end

      private

      ##
      # Finds the incoming summon based on the provided parameters.
      #
      # Sets the @incoming_summon instance variable.
      #
      # @return [void]
      def find_incoming_summon
        @incoming_summon = find_by_any_id(Summon, summon_params[:summon_id])
      end

      ##
      # Builds a new GridSummon instance using permitted parameters.
      #
      # Merges the party id and the incoming summon id into the parameters.
      #
      # @return [GridSummon] A new grid summon instance.
      def build_grid_summon
        GridSummon.new(summon_params.merge(party_id: party.id, summon_id: incoming_summon.id))
      end

      ##
      # Checks whether the grid summon error is solely due to a conflict.
      #
      # Verifies if the errors on the :series attribute include the specific conflict message
      # and confirms that a conflict exists for the current party.
      #
      # @param grid_summon [GridSummon] The grid summon instance to check.
      # @return [Boolean] True if the error is due solely to a conflict, false otherwise.
      def conflict_error?(grid_summon)
        grid_summon.errors[:series].include?('must not conflict with existing summons') &&
          grid_summon.conflicts(party).present?
      end

      ##
      # Defines and permits the whitelisted parameters for a grid summon.
      #
      # @return [ActionController::Parameters] The permitted parameters.
      def summon_params
        grid_item_params(:id, :summon_id, :collection_summon_id,
                         :position, :main, :friend, :quick_summon,
                         :uncap_level, :transcendence_step, :notes_synced)
      end

      ##
      # Specifies and permits the duplicate parameters.
      #
      # @return [ActionController::Parameters] the permitted parameters.
      def duplicate_params
        params.permit(:position)
      end
    end
  end
end
