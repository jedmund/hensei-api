# frozen_string_literal: true

module Api
  module V1
    class UpdateBlueprint < Blueprinter::Base
      fields :version, :update_type, :updated_at
    end
  end
end
