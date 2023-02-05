# frozen_string_literal: true

module Api
  module V1
    class JobAccessoriesController < Api::V1::ApiController
      def job
        accessories = JobAccessory.where('job_id = ?', params[:id])
        render json: JobAccessoryBlueprint.render(accessories)
      end
    end
  end
end
