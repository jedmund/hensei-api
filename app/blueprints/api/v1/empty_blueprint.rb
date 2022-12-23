# frozen_string_literal: true

module Api
  module V1
    class EmptyBlueprint < Blueprinter::Base
      field :available, if: ->(_field_name, _empty, options) { options.key?(:availability) } do |_, options|
        if options.key?(:email)
          User.where('email = ?', options[:email]).count.zero?
        elsif options.key?(:username)
          User.where('username = ?', options[:username]).count.zero?
        end
      end
    end
  end
end
