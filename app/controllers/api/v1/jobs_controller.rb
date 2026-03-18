# frozen_string_literal: true

module Api
  module V1
    class JobsController < Api::V1::ApiController
      include PartyAuthorizationConcern

      before_action :set_party, only: %w[update_job update_job_skills destroy_job_skill update_accessory destroy_accessory]
      before_action :authorize_party!, only: %w[update_job update_job_skills destroy_job_skill update_accessory destroy_accessory]
      before_action :set_job, only: %w[update]
      before_action :ensure_editor_role, only: %w[create update]

      def all
        render json: JobBlueprint.render(Job.all)
      end

      def show
        render json: JobBlueprint.render(Job.find_by(granblue_id: params[:id]))
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
        if job_params[:job_id] != -1
          # Extract job and find its main skills
          old_job = @party.job
          job = Job.find(job_params[:job_id])
          main_skills = JobSkill.where(job: job.id, main: true)

          # Update the party
          @party.job = job
          main_skills.each_with_index do |skill, index|
            @party["skill#{index}_id"] = skill.id
          end

          # Check for incompatible Base and EMP skills
          %w[skill1_id skill2_id skill3_id].each do |key|
            @party[key] = nil if @party[key] && mismatched_skill(@party.job, JobSkill.find(@party[key]))
          end

          # Remove extra subskills if necessary
          if old_job &&
            %w[1 2 3].include?(old_job.row) &&
            %w[4 5 ex2].include?(job.row) &&
            @party.skill1 && @party.skill2 && @party.skill3 &&
            @party.skill1.sub && @party.skill2.sub && @party.skill3.sub
            @party['skill3_id'] = nil
          end
        else
          @party.job = nil
          %w[skill0_id skill1_id skill2_id skill3_id].each do |key|
            @party[key] = nil
          end
        end

        @party.save!
        render json: PartyBlueprint.render(@party, view: :job_metadata)
      end

      def update_job_skills
        raise Api::V1::NoJobSkillProvidedError unless job_params[:skill1_id] || job_params[:skill2_id] || job_params[:skill3_id]

        # Determine which incoming keys contain new skills
        skill_keys = %w[skill1_id skill2_id skill3_id]
        new_skill_keys = job_params.keys.select { |key| skill_keys.include?(key) }

        # If there are new skills, merge them with the existing skills
        unless new_skill_keys.empty?
          # Load skills ONCE upfront to avoid N+1 queries
          new_skill_ids = new_skill_keys.map { |key| job_params[key] }
          new_skills_loaded = JobSkill.where(id: new_skill_ids).index_by(&:id)

          # Validate all skills exist and are compatible
          new_skill_ids.each do |id|
            skill = new_skills_loaded[id]
            raise ActiveRecord::RecordNotFound.new("Couldn't find JobSkill") unless skill
            raise Api::V1::IncompatibleSkillError.new(job: @party.job, skill: skill) if mismatched_skill(@party.job, skill)
          end

          existing_skills = {
            1 => @party.skill1,
            2 => @party.skill2,
            3 => @party.skill3
          }

          positions = extract_positions_from_keys(new_skill_keys)
          # Pass loaded skills instead of IDs
          merged = merge_skills_with_loaded_skills(existing_skills, new_skill_ids.map { |id| new_skills_loaded[id] }, positions)

          skill_ids_hash = merged.each_with_object({}) do |(index, skill), memo|
            memo["skill#{index}_id"] = skill&.id
          end

          @party.attributes = skill_ids_hash
        end

        @party.save!
        render json: PartyBlueprint.render(@party, view: :job_metadata)
      end

      def destroy_job_skill
        position = job_params[:skill_position].to_i
        @party["skill#{position}_id"] = nil
        render json: PartyBlueprint.render(@party, view: :job_metadata) if @party.save
      end

      def update_accessory
        @party.accessory = JobAccessory.find(job_params[:accessory_id])
        @party.save!
        render json: PartyBlueprint.render(@party, view: :job_metadata)
      end

      def destroy_accessory
        @party.accessory = nil
        @party.save!
        render json: PartyBlueprint.render(@party, view: :job_metadata)
      end

      private

      def merge_skills_with_loaded_skills(existing_skills, new_skills, positions)
        # new_skills is now an array of already-loaded JobSkill objects
        new_skills.each_with_index do |skill, index|
          existing_skills = place_skill_in_existing_skills(existing_skills, skill, positions[index])
        end

        existing_skills
      end

      def place_skill_in_existing_skills(existing_skills, skill, position)
        # Test if skill will exceed allowances of skill types
        skill_type = skill.sub ? 'sub' : 'emp'

        unless can_add_skill_of_type(existing_skills, position, skill_type)
          raise Api::V1::TooManySkillsOfTypeError.new(skill_type: skill_type)
        end

        if !existing_skills[position]
          existing_skills[position] = skill
        else
          value = existing_skills.compact.detect { |_, value| value && value.id == skill.id }
          old_position = existing_skills.key(value[1]) if value

          if old_position
            existing_skills = swap_skills_at_position(existing_skills, skill, position, old_position)
          else
            existing_skills[position] = skill
          end
        end

        existing_skills
      end

      def swap_skills_at_position(skills, new_skill, position1, position2)
        # Check desired position for a skill
        displaced_skill = skills[position1] if skills[position1].present?

        # Put skill in new position
        skills[position1] = new_skill
        skills[position2] = displaced_skill

        skills
      end

      def extract_positions_from_keys(keys)
        # Subtract by 1 because we won't operate on the 0th skill, so we don't pass it
        keys.map { |key| key['skill'.length].to_i }
      end

      def can_add_skill_of_type(skills, position, type)
        if %w[4 5 ex2].include?(@party.job.row) && skills.values.compact.length.positive?
          max_skill_of_type = 2
          skills_to_check = skills.compact.reject { |key, _| key == position }

          sum = skills_to_check.values.count { |value| value.send(type) }
          return sum + 1 <= max_skill_of_type
        end

        true
      end

      def mismatched_skill(job, skill)
        mismatched_main = (skill.job.id != job.id) && skill.main && !skill.sub
        mismatched_emp = (skill.job.id != job.id && skill.job.base_job.id != job.base_job.id) && skill.emp
        mismatched_base = skill.job.base_job && (job.row != 'ex2' || skill.job.base_job.id != job.base_job.id) && skill.base

        if %w[4 5 ex2].include?(job.row)
          if skill.base && !mismatched_base
            false
          elsif mismatched_emp || mismatched_main
            true
          end
        elsif mismatched_emp || mismatched_main
          true
        else
          false
        end
      end

      def set_party
        @party = Party.find_by(shortcode: params[:id])
        render_not_found_response('party') unless @party
      end

      def set_job
        @job = Job.find_by(granblue_id: params[:id])
        render_not_found_response('job') unless @job
      end

      # Ensures the current user has editor role (role >= 7)
      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[JOBS] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end

      def job_update_params
        params.permit(
          :name_en, :name_jp, :granblue_id,
          :proficiency1, :proficiency2, :row, :order,
          :master_level, :ultimate_mastery,
          :accessory, :accessory_type, :base_job_id
        )
      end

      def job_params
        params.require(:party).permit(
          :job_id,
          :accessory_id,
          :skill0_id,
          :skill1_id,
          :skill2_id,
          :skill3_id,
          :skill_position
        )
      end
    end
  end
end
