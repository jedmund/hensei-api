module Api
  module V1
    class SupportSummonsController < ApiController
      before_action :set_target_user, only: %i[index]
      before_action :check_support_summons_access, only: %i[index]
      before_action :restrict_access, only: %i[create update destroy import]
      before_action :set_support_summon_for_write, only: %i[update destroy]

      def index
        @support_summons = @target_user.support_summons
                                       .includes(collection_summon: { summon: :summon_series })
                                       .ordered

        render json: Api::V1::SupportSummonBlueprint.render(
          @support_summons,
          root: :support_summons
        )
      end

      def create
        @support_summon = current_user.support_summons.build(support_summon_params)

        if @support_summon.save
          render json: Api::V1::SupportSummonBlueprint.render(@support_summon, view: :full),
                 status: :created
        else
          render_validation_error_response(@support_summon)
        end
      end

      def update
        if @support_summon.update(support_summon_params)
          render json: Api::V1::SupportSummonBlueprint.render(@support_summon, view: :full)
        else
          render_validation_error_response(@support_summon)
        end
      end

      def destroy
        @support_summon.destroy
        head :no_content
      end

      # POST /api/v1/support_summons/import
      # Imports a user's profile Support Summon set from the Chrome extension's
      # parsed HTML payload. Translates GBF section indices to our internal
      # enum, auto-creates missing CollectionSummons using the level-derived
      # uncap/transcendence, and atomically replaces the user's existing slots.
      def import
        items = import_params[:support_summons] || []
        service = SupportSummonImportService.new(current_user, items.map(&:to_unsafe_h))
        result = service.import

        if result.success?
          render json: Api::V1::SupportSummonBlueprint.render(
            result.created,
            root: :support_summons,
            meta: { created: result.created.size }
          ), status: :ok
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      private

      # `user_id` accepts either the UUID primary key or a (case-insensitive)
      # username so the route is consistent with other user-keyed endpoints.
      def set_target_user
        identifier = params[:user_id].to_s
        @target_user = User.find_by('lower(username) = ?', identifier.downcase) ||
                       User.find_by(id: identifier)
        return if @target_user

        render json: { error: 'User not found' }, status: :not_found
      end

      def check_support_summons_access
        return if @target_user.nil?

        return if @target_user.support_summons_viewable_by?(current_user)

        render json: { error: 'You do not have permission to view these support summons' },
               status: :forbidden
      end

      def set_support_summon_for_write
        @support_summon = current_user.support_summons.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Support summon not found' }, status: :not_found
      end

      def support_summon_params
        params.require(:support_summon).permit(:collection_summon_id, :section, :position)
      end

      def import_params
        params.permit(support_summons: [:gbf_section, :position, :granblue_id, :level])
      end
    end
  end
end
