# frozen_string_literal: true

module Api
  module V1
    class UserRaidElementsController < Api::V1::ApiController
      before_action :doorkeeper_authorize!, only: %i[index sync]

      # GET /user_raid_elements - current user's raid elements
      def index
        elements = current_user.user_raid_elements.includes(:raid)
        render json: { user_raid_elements: grouped_elements(elements) }
      end

      # PUT /user_raid_elements/sync - bulk sync elements for a raid
      # Expects: { raid_id: "...", elements: [1, 3, 5] }
      def sync
        raid = Raid.find_by(id: params[:raid_id])
        return render_not_found_response('raid') unless raid
        return render json: { error: 'Raid is not trackable' }, status: :unprocessable_entity unless raid.trackable

        elements = Array(params[:elements]).map(&:to_i).select { |e| (1..6).cover?(e) }

        ActiveRecord::Base.transaction do
          current_user.user_raid_elements.where(raid_id: raid.id).destroy_all
          elements.each do |element|
            current_user.user_raid_elements.create!(raid_id: raid.id, element: element)
          end
        end

        updated = current_user.user_raid_elements.where(raid_id: raid.id).includes(:raid)
        render json: { user_raid_elements: grouped_elements(updated) }
      end

      # GET /users/:user_id/raid_elements - view another user's elements (crew members only)
      def for_user
        target_user = User.find_by('lower(username) = ?', params[:user_id].downcase) ||
                      User.find_by(id: params[:user_id])
        return render_not_found_response('user') unless target_user

        elements = target_user.user_raid_elements.includes(:raid)
        render json: { user_raid_elements: grouped_elements(elements) }
      end

      private

      # Group elements by raid for a cleaner API response
      def grouped_elements(elements)
        elements.group_by(&:raid_id).map do |raid_id, raid_elements|
          raid = raid_elements.first.raid
          {
            raid_id: raid_id,
            raid_name: { en: raid.name_en, ja: raid.name_jp },
            elements: raid_elements.map(&:element).sort
          }
        end
      end
    end
  end
end
