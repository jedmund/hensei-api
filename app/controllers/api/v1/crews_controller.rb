# frozen_string_literal: true

module Api
  module V1
    class CrewsController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew, only: %i[show update members roster leave transfer_captain shared_parties]
      before_action :require_crew!, only: %i[show update members roster shared_parties]
      before_action :authorize_crew_member!, only: %i[show members shared_parties]
      before_action :authorize_crew_officer!, only: %i[update roster]
      before_action :authorize_crew_captain!, only: %i[transfer_captain]

      # GET /crew or GET /crews/:id
      def show
        render json: CrewBlueprint.render(@crew, view: :full, root: :crew, current_user: current_user)
      end

      # POST /crews
      def create
        raise CrewErrors::AlreadyInCrewError if current_user.crew.present?

        @crew = Crew.new(crew_params)

        ActiveRecord::Base.transaction do
          @crew.save!
          CrewMembership.create!(crew: @crew, user: current_user, role: :captain)
        end

        render json: CrewBlueprint.render(@crew.reload, view: :full, root: :crew, current_user: current_user), status: :created
      end

      # PUT /crew
      def update
        if @crew.update(crew_params)
          render json: CrewBlueprint.render(@crew, view: :full, root: :crew, current_user: current_user)
        else
          render_validation_error_response(@crew)
        end
      end

      # GET /crew/members
      # Params:
      #   filter: 'active' (default), 'retired', 'phantom', 'all'
      def members
        filter = params[:filter]&.to_sym || :active

        case filter
        when :active
          members = @crew.active_memberships.includes(user: { active_crew_membership: :crew }).order(role: :desc, created_at: :asc)
          phantoms = @crew.phantom_players.not_deleted.active.includes(:claimed_by).order(:name)
        when :retired
          members = @crew.crew_memberships.retired.includes(:user).order(retired_at: :desc)
          phantoms = @crew.phantom_players.not_deleted.retired.includes(:claimed_by).order(:name)
        when :phantom
          members = []
          phantoms = @crew.phantom_players.not_deleted.includes(:claimed_by).order(:name)
        when :all
          members = @crew.crew_memberships.includes(user: { active_crew_membership: :crew }).order(role: :desc, retired: :asc, created_at: :asc)
          phantoms = @crew.phantom_players.not_deleted.includes(:claimed_by).order(:name)
        else
          members = @crew.active_memberships.includes(user: { active_crew_membership: :crew }).order(role: :desc, created_at: :asc)
          phantoms = @crew.phantom_players.not_deleted.active.includes(:claimed_by).order(:name)
        end

        render json: {
          members: CrewMembershipBlueprint.render_as_hash(members, view: :with_user),
          phantoms: PhantomPlayerBlueprint.render_as_hash(phantoms, view: :with_claimed_by)
        }
      end

      # POST /crew/leave
      def leave
        membership = current_user.active_crew_membership
        raise CrewErrors::NotInCrewError unless membership
        raise CrewErrors::CaptainCannotLeaveError if membership.captain?

        membership.retire!
        head :no_content
      end

      # GET /crew/roster
      # Returns collection ownership for crew members based on requested item IDs
      # Params: character_ids[], weapon_ids[], summon_ids[]
      def roster
        members = @crew.active_memberships.includes(:user)
        user_ids = members.map(&:user_id)

        # Batch-load all collection items for all members at once
        @roster_cache = preload_roster_collections(user_ids)

        render json: {
          members: members.map { |m| build_member_roster(m) }
        }
      end

      # POST /crews/:id/transfer_captain
      def transfer_captain
        new_captain_id = params[:user_id]
        new_captain_membership = @crew.active_memberships.find_by(user_id: new_captain_id)

        raise CrewErrors::MemberNotFoundError unless new_captain_membership

        ActiveRecord::Base.transaction do
          current_user.active_crew_membership.update!(role: :vice_captain)
          new_captain_membership.update!(role: :captain)
        end

        render json: CrewBlueprint.render(@crew.reload, view: :full, root: :crew, current_user: current_user)
      end

      # GET /crew/shared_parties
      # Returns parties that have been shared with this crew
      def shared_parties
        parties = @crew.shared_parties
                       .includes(
                         :user, :job, { raid: :group },
                         { characters: [{ character: :character_series_records }, :grid_artifact] },
                         { weapons: { weapon: [:weapon_series, :weapon_series_variant] } },
                         { summons: [{ summon: :summon_series }] }
                       )
                       .order(created_at: :desc)
                       .paginate(page: params[:page], per_page: page_size)

        render json: {
          parties: PartyBlueprint.render_as_hash(parties, view: :preview, current_user: current_user),
          meta: pagination_meta(parties)
        }
      end

      # POST /check/gamertag
      def check_gamertag
        gamertag = params[:gamertag]&.strip
        available = gamertag.present? && !Crew.where('lower(gamertag) = ?', gamertag.downcase).where.not(id: current_user&.crew&.id).exists?
        render json: { available: available }
      end

      private

      def set_crew
        @crew = if params[:id]
                  Crew.includes(crew_memberships: { user: { active_crew_membership: :crew } }).find(params[:id])
                else
                  current_user&.crew
                end
      end

      def crew_params
        params.require(:crew).permit(:name, :gamertag, :granblue_crew_id, :description)
      end

      def require_crew!
        render_not_found_response('crew') unless @crew
      end

      def build_member_roster(membership)
        user = membership.user
        {
          user_id: user.id,
          username: user.username,
          role: membership.role,
          characters: find_collection_items(user, :characters),
          weapons: find_collection_items(user, :weapons),
          summons: find_collection_items(user, :summons)
        }
      end

      def preload_roster_collections(user_ids)
        char_ids = params[:character_ids]
        weap_ids = params[:weapon_ids]
        summ_ids = params[:summon_ids]

        cache = { characters: {}, weapons: {}, summons: {} }

        if char_ids.present?
          CollectionCharacter.includes(:character).where(user_id: user_ids, character_id: char_ids)
            .each { |item| (cache[:characters][item.user_id] ||= []) << item }
        end

        if weap_ids.present?
          CollectionWeapon.includes(:weapon).where(user_id: user_ids, weapon_id: weap_ids)
            .each { |item| (cache[:weapons][item.user_id] ||= []) << item }
        end

        if summ_ids.present?
          CollectionSummon.includes(:summon).where(user_id: user_ids, summon_id: summ_ids)
            .each { |item| (cache[:summons][item.user_id] ||= []) << item }
        end

        cache
      end

      def find_collection_items(user, type)
        ids = params["#{type.to_s.singularize}_ids"]
        return [] if ids.blank?

        collection = @roster_cache[type][user.id] || []

        collection.map do |item|
          canonical = case type
                      when :characters then item.character
                      when :weapons then item.weapon
                      when :summons then item.summon
                      end

          result = {
            id: item_id_for(item, type),
            uncap_level: item.uncap_level,
            transcendence_step: item.transcendence_step,
            flb: canonical&.flb
          }

          if type == :characters
            result[:special] = canonical&.special
            result[:transcendence] = !canonical&.special && canonical&.transcendence
          else
            result[:ulb] = canonical&.ulb
            result[:transcendence] = canonical&.transcendence
          end

          result
        end
      end

      def item_id_for(item, type)
        case type
        when :characters then item.character_id
        when :weapons then item.weapon_id
        when :summons then item.summon_id
        end
      end
    end
  end
end
