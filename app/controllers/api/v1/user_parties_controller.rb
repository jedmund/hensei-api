# frozen_string_literal: true

module Api
  module V1
    class UserPartiesController < Api::V1::ApiController
      include PartyQueryingConcern

      before_action :set_user

      def index
        skip_privacy = current_user&.id == @user.id
        base_query = build_preview_base_query.where(user_id: @user.id)

        query = PartyQueryBuilder.new(
          base_query,
          params: params,
          current_user: current_user,
          options: { skip_privacy: skip_privacy, admin_mode: admin_mode }
        ).build

        parties = query.paginate(page: params[:page], per_page: page_size)

        render json: Api::V1::PartyBlueprint.render(
          parties,
          view: :list,
          root: :results,
          meta: pagination_meta(parties)
        )
      end

      private

      def set_user
        @user = User.find_by(username: params[:user_id])
        render_not_found_response('user') unless @user
      end
    end
  end
end
