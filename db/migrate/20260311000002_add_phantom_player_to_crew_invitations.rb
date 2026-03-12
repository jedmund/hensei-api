# frozen_string_literal: true

class AddPhantomPlayerToCrewInvitations < ActiveRecord::Migration[8.0]
  def change
    add_reference :crew_invitations, :phantom_player, type: :uuid, foreign_key: true, null: true
  end
end
