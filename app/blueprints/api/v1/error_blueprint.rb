# frozen_string_literal: true

module Api
  module V1
    class ErrorBlueprint < Blueprinter::Base
      field :error, if: ->(_field_name, _error, options) { options.key?(:error) } do |_, options|
        options[:error]
      end

      field :errors, if: ->(_field_name, _error, options) { options.key?(:errors) } do |_, options|
        options[:errors]
      end
    end
  end
end
