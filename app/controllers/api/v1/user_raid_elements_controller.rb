# frozen_string_literal: true

module Api
  module V1
    class UserRaidElementsController < Api::V1::ApiController
      before_action :restrict_access, only: %i[index sync]

      # GET /user_raid_elements
      # Returns current user's elements grouped by raid
      def index
        elements = current_user.user_raid_elements.includes(:raid)

        render json: grouped_response(elements)
      end

      # PUT /user_raid_elements/sync
      # Bulk replace elements for a specific raid
      def sync
        raid = Raid.find(params[:raid_id])
        element_ids = Array(params[:elements]).map(&:to_i)

        UserRaidElement.transaction do
          current_user.user_raid_elements.where(raid: raid).delete_all

          element_ids.each do |element|
            current_user.user_raid_elements.create!(raid: raid, element: element)
          end
        end

        elements = current_user.user_raid_elements.includes(:raid).where(raid: raid)
        render json: grouped_response(elements)
      end

      # GET /users/:user_id/raid_elements
      # View another user's elements by username
      def for_user
        user = User.find_by!(username: params[:user_id])

        elements = user.user_raid_elements.includes(:raid)

        render json: grouped_response(elements)
      end

      private

      def grouped_response(elements)
        elements.group_by(&:raid_id).map do |raid_id, raid_elements|
          raid = raid_elements.first.raid
          {
            raid_id: raid_id,
            raid_name: { en: raid.name_en, ja: raid.name_jp },
            elements: raid_elements.map(&:element)
          }
        end
      end
    end
  end
end
