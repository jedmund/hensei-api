# frozen_string_literal: true

module Api
  module V1
    class JobAccessoriesController < Api::V1::ApiController
      before_action :doorkeeper_authorize!, only: %i[create update destroy]
      before_action :ensure_editor_role, only: %i[create update destroy]

      # GET /job_accessories
      # Optional filter: ?accessory_type=1 (1=Shield, 2=Manatura)
      def index
        accessories = JobAccessory.includes(:job).all
        accessories = accessories.where(accessory_type: params[:accessory_type]) if params[:accessory_type].present?
        accessories = accessories.order(:accessory_type, :granblue_id)
        render json: JobAccessoryBlueprint.render(accessories)
      end

      # GET /job_accessories/:id
      # Supports lookup by granblue_id or uuid
      def show
        accessory = find_accessory
        return render_not_found_response('job_accessory') unless accessory

        render json: JobAccessoryBlueprint.render(accessory)
      end

      # POST /job_accessories
      def create
        accessory = JobAccessory.new(job_accessory_params)
        if accessory.save
          render json: JobAccessoryBlueprint.render(accessory), status: :created
        else
          render_validation_error_response(accessory)
        end
      end

      # PUT /job_accessories/:id
      def update
        accessory = find_accessory
        return render_not_found_response('job_accessory') unless accessory

        if accessory.update(job_accessory_params)
          render json: JobAccessoryBlueprint.render(accessory)
        else
          render_validation_error_response(accessory)
        end
      end

      # DELETE /job_accessories/:id
      def destroy
        accessory = find_accessory
        return render_not_found_response('job_accessory') unless accessory

        accessory.destroy
        head :no_content
      end

      # GET /jobs/:id/accessories
      # Legacy endpoint - get accessories for a specific job
      def job
        job = Job.find_by(granblue_id: params[:id]) || Job.find_by(id: params[:id])
        return render_not_found_response('job') unless job

        accessories = JobAccessory.where(job_id: job.id)
        render json: JobAccessoryBlueprint.render(accessories)
      end

      private

      def find_accessory
        JobAccessory.find_by(granblue_id: params[:id]) || JobAccessory.find_by(id: params[:id])
      end

      def job_accessory_params
        params.permit(:name_en, :name_jp, :granblue_id, :rarity, :release_date, :accessory_type, :job_id)
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[JOB_ACCESSORIES] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end
    end
  end
end
