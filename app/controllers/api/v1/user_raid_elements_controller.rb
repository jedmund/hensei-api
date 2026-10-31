# frozen_string_literal: true

module Api
  module V1
    # Which elements a user has teams for in each trackable raid. Users edit
    # only their own; crewmates can read each other's, matching who can open
    # a crew member page.
    class UserRaidElementsController < Api::V1::ApiController
      before_action :restrict_access

      # GET /user_raid_elements
      def index
        render json: grouped_response(current_user)
      end

      # PUT /user_raid_elements/sync
      # Replaces the current user's elements for one trackable raid.
      def sync
        raid = Raid.find(params.require(:raid_id))
        return render_sync_error('Raid is not trackable', 'raid_not_trackable') unless raid.trackable?

        elements = requested_elements
        return render_sync_error('Elements must be game element ids', 'invalid_elements') if elements.nil?

        UserRaidElement.transaction do
          current_user.user_raid_elements.where(raid: raid).delete_all
          elements.each { |element| current_user.user_raid_elements.create!(raid: raid, element: element) }
        end

        render json: grouped_response(current_user, raid: raid)
      end

      # GET /users/:user_id/raid_elements
      def for_user
        user = User.with_username(params[:user_id]).first!
        return render_forbidden unless user == current_user || user.in_same_crew_as?(current_user)

        render json: grouped_response(user)
      end

      private

      # The deduplicated element ids, or nil when any isn't a game element.
      def requested_elements
        raw = params[:elements]
        return [] if raw.blank?
        return nil unless raw.is_a?(Array)

        elements = raw.map { |value| Integer(value.to_s, exception: false) }
        return nil unless elements.all? { |element| UserRaidElement::ELEMENTS.include?(element) }

        elements.uniq.sort
      end

      def grouped_response(user, raid: nil)
        scope = user.user_raid_elements.joins(:raid).merge(Raid.trackable).includes(:raid).order(:element)
        scope = scope.where(raid: raid) if raid

        scope.group_by(&:raid).map do |grouped_raid, rows|
          {
            raid_id: grouped_raid.id,
            raid_name: { en: grouped_raid.name_en, ja: grouped_raid.name_jp },
            elements: rows.map(&:element)
          }
        end
      end

      def render_sync_error(message, code)
        render json: ErrorBlueprint.render(nil, error: { message: message, code: code }),
               status: :unprocessable_entity
      end

      def render_forbidden
        render json: ErrorBlueprint.render(nil, error: { message: 'Not in the same crew', code: 'forbidden' }),
               status: :forbidden
      end
    end
  end
end
