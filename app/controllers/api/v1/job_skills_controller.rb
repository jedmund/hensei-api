# frozen_string_literal: true

module Api
  module V1
    class JobSkillsController < Api::V1::ApiController
      before_action :doorkeeper_authorize!, only: %i[create update destroy download_image]
      before_action :ensure_editor_role, only: %i[create update destroy download_image]

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

      # POST /jobs/:job_id/skills
      def create
        job = Job.find_by(granblue_id: params[:job_id])
        return render_not_found_response('job') unless job

        skill = job.skills.build(job_skill_params)
        if skill.save
          render json: JobSkillBlueprint.render(skill), status: :created
        else
          render_validation_error_response(skill)
        end
      end

      # PUT /jobs/:job_id/skills/:id
      def update
        skill = JobSkill.find(params[:id])
        if skill.update(job_skill_params)
          render json: JobSkillBlueprint.render(skill)
        else
          render_validation_error_response(skill)
        end
      end

      # DELETE /jobs/:job_id/skills/:id
      def destroy
        skill = JobSkill.find(params[:id])
        skill.destroy
        head :no_content
      end

      # POST /jobs/:job_id/skills/:id/download_image
      def download_image
        skill = JobSkill.find(params[:id])
        return render json: { error: 'No image_id' }, status: :unprocessable_entity unless skill.image_id.present?
        return render json: { error: 'No slug' }, status: :unprocessable_entity unless skill.slug.present?

        downloader = Granblue::Downloaders::JobSkillDownloader.new(skill.image_id, slug: skill.slug, storage: :s3)
        result = downloader.download

        render json: { success: result[:success], filename: "#{skill.slug}.png" }
      end

      private

      def job_skill_params
        params.permit(:name_en, :name_jp, :slug, :color, :main, :base, :sub, :emp, :order,
                      :image_id, :action_id)
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[JOB_SKILLS] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end
    end
  end
end
