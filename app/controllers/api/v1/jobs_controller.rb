# frozen_string_literal: true

module Api
  module V1
    class JobsController < Api::V1::ApiController
      include PartyAuthorizationConcern

      # What an editor may write; the admin schema publishes it (GBF-143).
      PERMITTED = %i[
        name_en name_jp granblue_id
        proficiency1 proficiency2 row order
        master_level ultimate_mastery aux_weapon
        accessory accessory_type base_job_id
      ].freeze

      before_action :set_party, only: %w[update_job update_job_skills destroy_job_skill update_accessory destroy_accessory]
      before_action :authorize_party!, only: %w[update_job update_job_skills destroy_job_skill update_accessory destroy_accessory]
      before_action :set_job, only: %w[show update]
      before_action :ensure_editor_role, only: %w[create update]

      def all
        render json: JobBlueprint.render(Job.all)
      end

      def show
        render json: JobBlueprint.render(@job)
      end

      # POST /jobs
      # Creates a new job record
      def create
        @job = Job.new(job_update_params)

        if @job.save
          render json: JobBlueprint.render(@job), status: :created
        else
          render_validation_error_response(@job)
        end
      end

      # PATCH/PUT /jobs/:id
      # Updates an existing job record
      def update
        if @job.update(job_update_params)
          render json: JobBlueprint.render(@job)
        else
          render_validation_error_response(@job)
        end
      end

      def update_job
        PartyJobSkills.new(@party).change_job(job_params[:job_id])
        save_and_render_party
      end

      def update_job_skills
        PartyJobSkills.new(@party).equip(job_params)
        save_and_render_party
      end

      def destroy_job_skill
        position = job_params[:skill_position].to_i
        @party["skill#{position}_id"] = nil
        @party.last_updated = Time.current
        render json: PartyBlueprint.render(@party, view: :job_metadata) if @party.save
      end

      def update_accessory
        @party.accessory = JobAccessory.find(job_params[:accessory_id])
        save_and_render_party
      end

      def destroy_accessory
        @party.accessory = nil
        save_and_render_party
      end

      private

      def save_and_render_party
        @party.last_updated = Time.current
        @party.save!
        render json: PartyBlueprint.render(@party, view: :job_metadata)
      end

      def set_party
        @party = Party.find_by(shortcode: params[:id])
        render_not_found_response('party') unless @party
      end

      def set_job
        @job = Job.find_by_route_id(params[:id])
        render_not_found_response('job') unless @job
      end

      def job_update_params
        params.permit(*PERMITTED)
      end

      def job_params
        params.expect(party: %i[job_id accessory_id skill0_id skill1_id skill2_id skill3_id skill_position])
      end
    end
  end
end
