# frozen_string_literal: true

module Api
  module V1
    ##
    # Controller responsible for managing grid summons for a party.
    # Provides actions to create, update, and destroy grid summons.
    #
    # @note All actions assume that the request has been authorized.
    class GridSummonsController < Api::V1::ApiController
      attr_reader :party, :incoming_summon

      before_action :set, only: %w[update update_uncap_level update_quick_summon]
      before_action :find_party, only: :create
      before_action :find_incoming_summon, only: :create
      before_action :authorize, only: %i[create update update_uncap_level update_quick_summon destroy]

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
        # Build a new grid summon using permitted parameters merged with party and summon IDs.
        # Then, using `tap`, ensure that the uncap_level is set by using the max_uncap_level helper
        # if it hasn't already been provided.
        grid_summon = build_grid_summon.tap do |gs|
          gs.uncap_level ||= max_uncap_level(gs)
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
        @summon.attributes = summon_params

        return render json: GridSummonBlueprint.render(@summon, view: :nested, root: :grid_summon) if @summon.save

        render_validation_error_response(@summon)
      end

      ##
      # Updates the uncap level and transcendence step of a grid summon.
      #
      # This action recalculates the maximum allowed uncap level based on the summon attributes
      # and applies business logic to adjust the uncap level and transcendence step accordingly.
      # On success, it renders the updated grid summon view; otherwise, it renders a validation error response.
      #
      # @return [void]
      def update_uncap_level
        summon = @summon.summon
        max_level = max_uncap_level(summon)

        greater_than_max_uncap = summon_params[:uncap_level].to_i > max_level
        can_be_transcended = summon.transcendence &&
          summon_params[:transcendence_step].present? &&
          summon_params[:transcendence_step].to_i.positive?

        new_uncap_level = greater_than_max_uncap || can_be_transcended ? max_level : summon_params[:uncap_level]
        new_transcendence_step = summon.transcendence && summon_params[:transcendence_step].present? ? summon_params[:transcendence_step] : 0

        if @summon.update(uncap_level: new_uncap_level, transcendence_step: new_transcendence_step)
          render json: GridSummonBlueprint.render(@summon, view: :nested, root: :grid_summon)
        else
          render_validation_error_response(@summon)
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
        return if [4, 5, 6].include?(@summon.position)

        quick_summons = @summon.party.summons.select(&:quick_summon)

        quick_summons.each do |summon|
          summon.update!(quick_summon: false)
        end

        @summon.update!(quick_summon: summon_params[:quick_summon])
        return unless @summon.persisted?

        quick_summons -= [@summon]
        summons = [@summon] + quick_summons

        render json: GridSummonBlueprint.render(summons, view: :nested, root: :summons)
      end

      #
      # Destroys a grid summon.
      #
      # Finds the grid summon by ID. If not found, renders a not-found response.
      # If the current user is not authorized to perform the deletion, renders an unauthorized response.
      # On successful destruction, renders the destroyed grid summon view.
      #
      # @return [void]
      def destroy
        grid_summon = GridSummon.find_by('id = ?', params[:id])

        return render_not_found_response('grid_summon') if grid_summon.nil?
        return render_unauthorized_response if grid_summon.party.user != current_user

        render json: GridSummonBlueprint.render(grid_summon, view: :destroyed), status: :ok if grid_summon.destroy
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

        output = render_grid_summon_view(summon)
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

        output = render_grid_summon_view(conflict_summon, old_position)
        render json: output
      end

      private

      ##
      # Finds the party based on the provided party_id parameter.
      #
      # Sets the @party instance variable and renders an unauthorized response if the current
      # user is not the owner of the party.
      #
      # @return [void]
      def find_party
        # BUG: I can create grid weapons even when I'm not logged in on an authenticated party
        @party = Party.find(summon_params[:party_id])
        render_unauthorized_response if current_user && (party.user != current_user)
      end

      ##
      # Finds the incoming summon based on the provided parameters.
      #
      # Sets the @incoming_summon instance variable.
      #
      # @return [void]
      def find_incoming_summon
        @incoming_summon = Summon.find_by(id: summon_params[:summon_id])
      end

      ##
      # Finds and sets the grid summon for update actions.
      #
      # Sets the @summon instance variable using the provided id parameter.
      #
      # @return [void]
      def set
        @summon = GridSummon.find_by('id = ?', summon_params[:id])
      end

      ##
      # Authorizes the current request based on the party or grid summon ownership and edit key.
      #
      # Checks if the current user is authorized to create or update the party or grid summon.
      # Renders an unauthorized response if the authorization fails.
      #
      # @return [void]
      def authorize
        # Create
        unauthorized_create = @party && (@party.user != current_user || @party.edit_key != edit_key)
        unauthorized_update = @summon && @summon.party && (@summon.party.user != current_user || @summon.party.edit_key != edit_key)

        render_unauthorized_response if unauthorized_create || unauthorized_update
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
      # Renders the grid summon view with additional metadata.
      #
      # @param grid_summon [GridSummon] The grid summon instance to render.
      # @param conflict_position [Integer, nil] The position of a conflicting summon, if applicable.
      # @return [String] The rendered grid summon view as JSON.
      def render_grid_summon_view(grid_summon, conflict_position = nil)
        GridSummonBlueprint.render(grid_summon,
                                   view: :nested,
                                   root: :grid_summon,
                                   meta: { replaced: conflict_position })
      end

      ##
      # Determines the maximum uncap level for a given summon.
      #
      # The maximum uncap level is determined based on the attributes of the summon:
      # - Returns 4 if the summon has FLB but not ULB and is not transcended.
      # - Returns 5 if the summon has ULB and is not transcended.
      # - Returns 6 if the summon has transcendence.
      # - Otherwise, returns 3.
      #
      # @param summon [Summon] The summon for which to determine the maximum uncap level.
      # @return [Integer] The maximum uncap level.
      def max_uncap_level(summon)
        if summon.flb && !summon.ulb && !summon.transcendence
          4
        elsif summon.ulb && !summon.transcendence
          5
        elsif summon.transcendence
          6
        else
          3
        end
      end

      ##
      # Defines and permits the whitelisted parameters for a grid summon.
      #
      # @return [ActionController::Parameters] The permitted parameters.
      def summon_params
        params.require(:summon).permit(:id, :party_id, :summon_id, :position, :main, :friend,
                                       :quick_summon, :uncap_level, :transcendence_step)
      end
    end
  end
end
