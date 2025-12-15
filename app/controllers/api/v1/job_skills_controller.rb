# frozen_string_literal: true

module Api
  module V1
    class JobSkillsController < Api::V1::ApiController
      def all
        render json: JobSkillBlueprint.render(JobSkill.includes(:job).all)
      end

      # Returns skills that belong to a specific job
      def job
        job = Job.find_by(granblue_id: params[:id])
        return render_not_found_response('job') unless job

        @skills = JobSkill.includes(:job)
                          .where(job_id: job.id)
                          .order(:order)
        render json: JobSkillBlueprint.render(@skills)
      end

      # Returns EMP skills from other jobs (for party skill selection)
      def emp
        @skills = JobSkill.includes(:job)
                          .where.not(job_id: params[:id])
                          .where(emp: true)
        render json: JobSkillBlueprint.render(@skills)
      end
    end
  end
end
