# frozen_string_literal: true

module Api
  module V1
    class JobsController < Api::V1::ApiController
      before_action :set, only: %w[update_job update_job_skills]

      def all
        @jobs = Job.all
        render :all, status: :ok
      end

      def update_job
        raise NoJobProvidedError unless job_params[:job_id].present?

        # Extract job and find its main skills
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

        render :update, status: :ok if @party.save!
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

        render :update, status: :ok if @party.save!
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
        if skills.values.compact.length.positive?
          max_skill_of_type = 2
          skills_to_check = skills.compact.reject { |key, _| key == position }

          sum = skills_to_check.values.count { |value| value.send(type) }

          sum + 1 <= max_skill_of_type
        else
          true
        end
      end

      def mismatched_skill(job, skill)
        mismatched_main = (skill.job.id != job.id) && skill.main && !skill.sub
        mismatched_emp = (skill.job.id != job.id) && skill.emp
        mismatched_base = skill.job.base_job && (job.row != 'ex2' || skill.job.base_job.id != job.base_job.id) && skill.base

        if %w[4 5 ex2].include?(job.row)
          true if mismatched_emp || mismatched_base || mismatched_main
        elsif mismatched_emp || mismatched_main
          true
        else
          false
        end
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
          :skill3_id
        )
      end
    end
  end
end
