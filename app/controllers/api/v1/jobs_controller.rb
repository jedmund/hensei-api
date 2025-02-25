# frozen_string_literal: true

module Api
  module V1
    class JobsController < Api::V1::ApiController
      before_action :set, only: %w[update_job update_job_skills destroy_job_skill]
      before_action :authorize, only: %w[update_job update_job_skills destroy_job_skill]

      def all
        render json: JobBlueprint.render(Job.all)
      end

      def show
        render json: JobBlueprint.render(Job.find_by(granblue_id: params[:id]))
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

        render json: PartyBlueprint.render(@party, view: :job_metadata) if @party.save!
      end

      def update_job_skills
        throw NoJobSkillProvidedError unless job_params[:skill1_id] || job_params[:skill2_id] || job_params[:skill3_id]

        # Determine which incoming keys contain new skills
        skill_keys = %w[skill1_id skill2_id skill3_id]
        new_skill_keys = job_params.keys.select { |key| skill_keys.include?(key) }

        # If there are new skills, merge them with the existing skills
        unless new_skill_keys.empty?
          existing_skills = {
            1 => @party.skill1,
            2 => @party.skill2,
            3 => @party.skill3
          }

          new_skill_ids = new_skill_keys.map { |key| job_params[key] }
          new_skill_ids.map do |id|
            skill = JobSkill.find(id)
            raise Api::V1::IncompatibleSkillError.new(job: @party.job, skill: skill) if mismatched_skill(@party.job,
                                                                                                         skill)
          end

          positions = extract_positions_from_keys(new_skill_keys)
          new_skills = merge_skills_with_existing_skills(existing_skills, new_skill_ids, positions)

          new_skill_ids = new_skills.each_with_object({}) do |(index, skill), memo|
            memo["skill#{index}_id"] = skill.id if skill
          end

          @party.attributes = new_skill_ids
        end

        render json: PartyBlueprint.render(@party, view: :jobs) if @party.save!
      end

      def destroy_job_skill
        position = job_params[:skill_position].to_i
        @party["skill#{position}_id"] = nil
        render json: PartyBlueprint.render(@party, view: :jobs) if @party.save
      end

      private

      def merge_skills_with_existing_skills(
        existing_skills,
        new_skill_ids,
        positions
      )
        new_skills = new_skill_ids.map { |id| JobSkill.find(id) }

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

      def authorize
        render_unauthorized_response if @party.user != current_user || @party.edit_key != edit_key
      end

      def set
        @party = Party.where('id = ?', params[:id]).first
      end

      def job_params
        params.require(:party).permit(
          :job_id,
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
