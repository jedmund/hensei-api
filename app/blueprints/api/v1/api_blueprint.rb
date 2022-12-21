# frozen_string_literal: true

module Api
  module V1
    class ApiBlueprint < Blueprinter::Base
      identifier :id

      cattr_accessor :current_user
      cattr_writer :current_user
    end
  end
end
