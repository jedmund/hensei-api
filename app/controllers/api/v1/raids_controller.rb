# frozen_string_literal: true

module Api
  module V1
    class RaidsController < Api::V1::ApiController
      def all
        @raids = Raid.all
        render :all, status: :ok
      end
    end
  end
end
