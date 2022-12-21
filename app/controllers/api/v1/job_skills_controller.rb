# frozen_string_literal: true

module Api
  module V1
    class JobSkillsController < Api::V1::ApiController
      def all
        @skills = JobSkill.all
        render :all, status: :ok
      end

      def job
        job = Job.find(params[:id])

        @skills = JobSkill.where(job: job).or(JobSkill.where(sub: true))
        render :all, status: :ok
      end
    end
  end
end
