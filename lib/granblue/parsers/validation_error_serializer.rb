# frozen_string_literal: true

module Granblue
  module Parsers
    class ValidationErrorSerializer
      def initialize(record, field, details)
        @record = record
        @field = field
        @details = details
      end

      def serialize
        {
          resource: resource,
          field: field,
          code: code
        }
      end

      private

      def resource
        @record.class.to_s
      end

      def field
        @field.to_s
      end

      def code
        @details[:error].to_s
      end

      def underscored_resource_name
        @record.class.to_s.gsub('::', '').underscore
      end
    end
  end
end
