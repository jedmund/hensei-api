# frozen_string_literal: true

module Api
  module V1
    class JobSkillsController < Api::V1::ApiController
      def all
        render json: JobSkillBlueprint.render(JobSkill.all)
      end

      def job
        @skills = JobSkill.where('job_id != ? AND emp = ?', params[:id], true)
        render json: JobSkillBlueprint.render(@skills)
      end
    end
  end
end
