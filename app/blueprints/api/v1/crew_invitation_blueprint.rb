# frozen_string_literal: true

module Api
  module V1
    class CrewInvitationBlueprint < ApiBlueprint
      fields :status, :expires_at, :created_at

      view :default do
        field :crew do |invitation|
          CrewBlueprint.render_as_hash(invitation.crew, view: :minimal)
        end
      end

      view :with_user do
        field :user do |invitation|
          UserBlueprint.render_as_hash(invitation.user, view: :minimal)
        end
        field :invited_by do |invitation|
          UserBlueprint.render_as_hash(invitation.invited_by, view: :minimal)
        end
        field :crew do |invitation|
          CrewBlueprint.render_as_hash(invitation.crew, view: :minimal)
        end
      end

      view :for_invitee do
        field :crew do |invitation|
          CrewBlueprint.render_as_hash(invitation.crew, view: :full)
        end
        field :invited_by do |invitation|
          UserBlueprint.render_as_hash(invitation.invited_by, view: :minimal)
        end
      end
    end
  end
end
