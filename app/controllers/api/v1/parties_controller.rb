# frozen_string_literal: true

module Api
  module V1
    class PartiesController < Api::V1::ApiController
      before_action :set_from_slug,
                    except: %w[create destroy update index favorites]
      before_action :set, only: %w[update destroy]
      before_action :authorize, only: %w[update destroy]

      MAX_CHARACTERS = 5
      MAX_SUMMONS = 8
      MAX_WEAPONS = 13

      DEFAULT_MIN_CHARACTERS = 3
      DEFAULT_MIN_SUMMONS = 2
      DEFAULT_MIN_WEAPONS = 5

      DEFAULT_MAX_CLEAR_TIME = 5400

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
          return render json: PartyBlueprint.render(party, view: :created, root: :party),
                        status: :created
        end

        render_validation_error_response(@party)
      end

      def show
        return render json: PartyBlueprint.render(@party, view: :full, root: :party) if @party

        render_not_found_response('project')
      end

      def update
        @party.attributes = party_params.except(:skill1_id, :skill2_id, :skill3_id)

        # TODO: Validate accessory with job

        return render json: PartyBlueprint.render(@party, view: :full, root: :party) if @party.save

        render_validation_error_response(@party)
      end

      def destroy
        return render json: PartyBlueprint.render(@party, view: :destroyed, root: :checkin) if @party.destroy
      end

      def remix
        new_party = @party.amoeba_dup
        new_party.attributes = {
          user: current_user,
          name: remixed_name(@party.name),
          source_party: @party
        }

        new_party.local_id = party_params[:local_id] if !party_params.nil?

        if new_party.save
          render json: PartyBlueprint.render(new_party, view: :created, root: :party,
                                             meta: { remix: true })
        else
          render_validation_error_response(new_party)
        end
      end

      def index
        conditions = build_conditions

        @parties = Party.joins(:weapons)
                        .group('parties.id')
                        .having('count(distinct grid_weapons.weapon_id) > 2')
                        .where(conditions)
                        .where(name_quality)
                        .where(user_quality)
                        .where(original)
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

        conditions = build_conditions
        conditions[:favorites] = { user_id: current_user.id }

        @parties = Party.joins(:favorites)
                        .where(conditions)
                        .where(name_quality)
                        .where(user_quality)
                        .where(original)
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

      def authorize
        render_unauthorized_response if @party.user != current_user || @party.edit_key != edit_key
      end

      def build_conditions
        params = request.params

        unless params['recency'].blank?
          start_time = (DateTime.current - params['recency'].to_i.seconds)
                         .to_datetime.beginning_of_day
        end

        min_characters_count = params['characters_count'].blank? ? DEFAULT_MIN_CHARACTERS : params['characters_count'].to_i
        min_summons_count = params['summons_count'].blank? ? DEFAULT_MIN_SUMMONS : params['summons_count'].to_i
        min_weapons_count = params['weapons_count'].blank? ? DEFAULT_MIN_WEAPONS : params['weapons_count'].to_i
        max_clear_time = params['max_clear_time'].blank? ? DEFAULT_MAX_CLEAR_TIME : params['max_clear_time'].to_i

        {}.tap do |hash|
          # Basic filters
          hash[:element] = params['element'].to_i unless params['element'].blank?
          hash[:raid] = params['raid'] unless params['raid'].blank?
          hash[:created_at] = start_time..DateTime.current unless params['recency'].blank?

          # Advanced filters: Team parameters
          hash[:full_auto] = params['full_auto'].to_i unless params['full_auto'].blank? || params['full_auto'].to_i == -1
          hash[:auto_guard] = params['auto_guard'].to_i unless params['auto_guard'].blank? || params['auto_guard'].to_i == -1
          hash[:charge_attack] = params['charge_attack'].to_i unless params['charge_attack'].blank? || params['charge_attack'].to_i == -1

          # Turn count of 0 will not be displayed, so disallow on the frontend or set default to 1
          # How do we do the same for button count since that can reasonably be 1?
          # hash[:turn_count] = params['turn_count'].to_i unless params['turn_count'].blank? || params['turn_count'].to_i <= 0
          # hash[:button_count] = params['button_count'].to_i unless params['button_count'].blank?
          # hash[:clear_time] = 0..max_clear_time

          # Advanced filters: Object counts
          hash[:characters_count] = min_characters_count..MAX_CHARACTERS
          hash[:summons_count] = min_summons_count..MAX_SUMMONS
          hash[:weapons_count] = min_weapons_count..MAX_WEAPONS
        end
      end

      def original
        "source_party_id IS NULL" unless request.params['original'].blank? || request.params['original'] == "false"
      end

      def user_quality
        "user_id IS NOT NULL" unless request.params[:user_quality].blank? || request.params[:user_quality] == "false"
      end

      def name_quality
        low_quality = [
          "Untitled",
          "Remix of Untitled",
          "Remix of Remix of Untitled",
          "Remix of Remix of Remix of Untitled",
          "Remix of Remix of Remix of Remix of Untitled",
          "Remix of Remix of Remix of Remix of Remix of Untitled",
          "無題",
          "無題のリミックス",
          "無題のリミックスのリミックス",
          "無題のリミックスのリミックスのリミックス",
          "無題のリミックスのリミックスのリミックスのリミックス",
          "無題のリミックスのリミックスのリミックスのリミックスのリミックス"
        ]

        joined_names = low_quality.map { |name| "'#{name}'" }.join(',')

        "name NOT IN (#{joined_names})" unless request.params[:name_quality].blank? || request.params[:name_quality] == "false"
      end

      def remixed_name(name)
        blanked_name = {
          en: name.blank? ? 'Untitled team' : name,
          ja: name.blank? ? '無名の編成' : name
        }

        if current_user
          case current_user.language
          when 'en'
            "Remix of #{blanked_name[:en]}"
          when 'ja'
            "#{blanked_name[:ja]}のリミックス"
          end
        else
          "Remix of #{blanked_name[:en]}"
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
        return unless params[:party].present?

        params.require(:party).permit(
          :user_id,
          :local_id,
          :edit_key,
          :extra,
          :name,
          :description,
          :raid_id,
          :job_id,
          :accessory_id,
          :skill0_id,
          :skill1_id,
          :skill2_id,
          :skill3_id,
          :full_auto,
          :auto_guard,
          :auto_summon,
          :charge_attack,
          :clear_time,
          :button_count,
          :turn_count,
          :chain_count,
          :guidebook1_id,
          :guidebook2_id,
          :guidebook3_id
        )
      end
    end
  end
end
