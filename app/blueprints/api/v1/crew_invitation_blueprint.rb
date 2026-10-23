# frozen_string_literal: true

module Api
  module V1
    class CrewInvitationBlueprint < ApiBlueprint
      fields :status, :expires_at, :created_at

      # Base fields belong at the top level: an explicit `view :default` block
      # makes Blueprinter 1.3 loop forever while rendering. Views below override
      # :crew where they need a different shape.
      field :crew do |invitation|
        CrewBlueprint.render_as_hash(invitation.crew, view: :minimal)
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
        field :phantom_player do |invitation|
          invitation.phantom_player ? PhantomPlayerBlueprint.render_as_hash(invitation.phantom_player) : nil
        end
      end

      view :for_invitee do
        field :crew do |invitation|
          CrewBlueprint.render_as_hash(invitation.crew, view: :full)
        end
        field :invited_by do |invitation|
          UserBlueprint.render_as_hash(invitation.invited_by, view: :minimal)
        end
        field :phantom_player do |invitation|
          invitation.phantom_player ? PhantomPlayerBlueprint.render_as_hash(invitation.phantom_player) : nil
        end
      end
    end
  end
end
