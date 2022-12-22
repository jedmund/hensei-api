# frozen_string_literal: true

module Api
  module V1
    class JobSkillsController < Api::V1::ApiController
      def all
        render json: JobSkillBlueprint.render(JobSkill.all)
      end

      def job
        @skills = JobSkill.where(job: Job.find(params[:id]))
                          .or(JobSkill.where(sub: true))
        render json: JobSkillBlueprint.render(@skills)
      end
    end
  end
end
