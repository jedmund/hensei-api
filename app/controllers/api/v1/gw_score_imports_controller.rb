# frozen_string_literal: true

module Api
  module V1
    class GwScoreImportsController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew
      before_action :authorize_crew_officer!

      # POST /crew/import_gw_scores
      # Params: { event_number:, round:, is_cumulative:, members: [{ granblue_id:, name:, score: }] }
      def create
        event = GwEvent.find_by!(event_number: params[:event_number])
        participation = @crew.crew_gw_participations.find_or_create_by!(gw_event: event)

        membership_map = build_membership_map
        phantom_map = build_phantom_map

        results = []
        errors = []
        phantoms_created = 0

        params[:members].each_with_index do |member_data, index|
          gbf_id = member_data[:granblue_id].to_s

          membership_id = membership_map[gbf_id]
          phantom_id = phantom_map[gbf_id]

          # Create phantom if no match found
          if membership_id.nil? && phantom_id.nil?
            phantom = find_or_create_phantom(gbf_id, member_data[:name])
            phantom_id = phantom.id
            phantom_map[gbf_id] = phantom.id
            phantoms_created += 1 if phantom.previously_new_record?
          end

          score = participation.gw_individual_scores.find_or_initialize_by(
            crew_membership_id: membership_id,
            phantom_player_id: phantom_id,
            round: params[:round]
          )
          score.assign_attributes(
            score: member_data[:score],
            is_cumulative: params[:is_cumulative] || false,
            recorded_by: current_user
          )

          if score.save
            results << score
          else
            errors << { index: index, granblue_id: gbf_id, errors: score.errors.full_messages }
          end
        end

        render json: {
          imported: results.size,
          phantoms_created: phantoms_created,
          errors: errors
        }, status: errors.empty? ? :created : :multi_status
      end

      private

      def set_crew
        @crew = current_user.crew
        raise CrewErrors::NotInCrewError unless @crew
      end

      # User.granblue_id is integer in DB, game returns strings
      def build_membership_map
        @crew.active_memberships.includes(:user).each_with_object({}) do |membership, map|
          gbf_id = membership.user.granblue_id
          map[gbf_id.to_s] = membership.id if gbf_id.present?
        end
      end

      def build_phantom_map
        @crew.phantom_players.not_deleted.active.where.not(granblue_id: [nil, '']).each_with_object({}) do |phantom, map|
          map[phantom.granblue_id] = phantom.id
        end
      end

      def find_or_create_phantom(gbf_id, name)
        @crew.phantom_players.find_or_create_by!(granblue_id: gbf_id) do |phantom|
          phantom.name = name
        end
      end
    end
  end
end
