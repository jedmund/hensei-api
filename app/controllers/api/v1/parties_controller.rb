# frozen_string_literal: true

module Api
  module V1
    class PartiesController < Api::V1::ApiController
      before_action :set_from_slug,
                    except: %w[create destroy update index favorites]
      before_action :set, only: %w[update destroy]

      def create
        party = Party.new
        party.user = current_user if current_user
        party.attributes = party_params if party_params

        # unless party_params.empty?
        #   party.attributes = party_params
        #
        #   # TODO: Extract this into a different method
        #   job = Job.find(party_params['job_id']) if party_params['job_id'].present?
        #   if job
        #     job_skills = JobSkill.where(job: job.id, main: true)
        #     job_skills.each_with_index do |skill, index|
        #       party["skill#{index}_id"] = skill.id
        #     end
        #   end
        # end

        if party.save!
          return render json: PartyBlueprint.render(party, view: :full, root: :party),
                        status: :created
        end

        render_validation_error_response(@party)
      end

      def show
        return render json: PartyBlueprint.render(@party, view: :full, root: :party) if @party

        render_not_found_response('project')
      end

      def update
        render_unauthorized_response if @party.user != current_user

        @party.attributes = party_params.except(:skill1_id, :skill2_id, :skill3_id)

        return render json: PartyBlueprint.render(@party, view: :full, root: :party) if @party.save!

        render_validation_error_response(@party)
      end

      def destroy
        render_unauthorized_response if @party.user != current_user
        return render json: PartyBlueprint.render(@party, view: :destroyed, root: :checkin) if @party.destroy
      end

      def remix
      end

      def index
        conditions = build_conditions(request.params)

        @parties = Party.joins(:weapons)
                        .group('parties.id')
                        .having('count(distinct grid_weapons.weapon_id) > 2')
                        .where(conditions)
                        .order(created_at: :desc)
                        .paginate(page: request.params[:page], per_page: COLLECTION_PER_PAGE)
                        .each { |party| party.favorited = current_user ? party.is_favorited(current_user) : false }

        count = Party.where(conditions).count
        total_pages = count.to_f / COLLECTION_PER_PAGE > 1 ? (count.to_f / COLLECTION_PER_PAGE).ceil : 1

        render json: PartyBlueprint.render(@parties,
                                           view: :collection,
                                           root: :results,
                                           meta: {
                                             count: count,
                                             total_pages: total_pages,
                                             per_page: COLLECTION_PER_PAGE
                                           })
      end

      def favorites
        raise Api::V1::UnauthorizedError unless current_user

        conditions = build_conditions(request.params)
        conditions[:favorites] = { user_id: current_user.id }

        @parties = Party.joins(:favorites)
                        .where(conditions)
                        .order('favorites.created_at DESC')
                        .paginate(page: request.params[:page], per_page: COLLECTION_PER_PAGE)
                        .each { |party| party.favorited = party.is_favorited(current_user) }

        count = Party.joins(:favorites).where(conditions).count
        total_pages = count.to_f / COLLECTION_PER_PAGE > 1 ? (count.to_f / COLLECTION_PER_PAGE).ceil : 1

        render json: PartyBlueprint.render(@parties,
                                           view: :collection,
                                           root: :results,
                                           meta: {
                                             count: count,
                                             total_pages: total_pages,
                                             per_page: COLLECTION_PER_PAGE
                                           })
      end

      private

      def build_conditions(params)
        unless params['recency'].blank?
          start_time = (DateTime.current - params['recency'].to_i.seconds)
                         .to_datetime.beginning_of_day
        end

        {}.tap do |hash|
          hash[:element] = params['element'] unless params['element'].blank?
          hash[:raid] = params['raid'] unless params['raid'].blank?
          hash[:created_at] = start_time..DateTime.current unless params['recency'].blank?
          hash[:weapons_count] = 5..13
        end
      end

      def set_from_slug
        @party = Party.where('shortcode = ?', params[:id]).first
        if @party
          @party.favorited = current_user && @party ? @party.is_favorited(current_user) : false
        else
          render_not_found_response('party')
        end
      end

      def set
        @party = Party.where('id = ?', params[:id]).first
      end

      def party_params
        params.require(:party).permit(
          :user_id,
          :extra,
          :name,
          :description,
          :raid_id,
          :job_id,
          :skill0_id,
          :skill1_id,
          :skill2_id,
          :skill3_id,
          :full_auto,
          :auto_guard,
          :charge_attack,
          :clear_time,
          :button_count,
          :turn_count,
          :chain_count
        ) if params[:party].present?
      end
    end
  end
end
