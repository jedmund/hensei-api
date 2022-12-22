# frozen_string_literal: true

module Api
  module V1
    class EmptyBlueprint < Blueprinter::Base
      field :email_available, if: ->(_field_name, _empty, options) { options.key?(:email) } do |_, options|
        User.where('email = ?', options[:email]).count.zero?
      end

      field :username_available, if: ->(_field_name, _empty, options) { options.key?(:username) } do |_, options|
        User.where('username = ?', options[:username]).count.zero?
      end
    end
  end
end
