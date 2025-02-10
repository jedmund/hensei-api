# frozen_string_literal: true

module Api
  module V1
    class JobSkillsController < Api::V1::ApiController
      def all
        render json: JobSkillBlueprint.render(JobSkill.includes(:job).all)
      end

      def job
        @skills = JobSkill.includes(:job)
                          .where.not(job_id: params[:id])
                          .where(emp: true)
        render json: JobSkillBlueprint.render(@skills)
      end
    end
  end
end
