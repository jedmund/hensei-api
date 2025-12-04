# frozen_string_literal: true

class CreateCrewInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :crew_invitations, id: :uuid do |t|
      t.references :crew, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true, comment: 'Invitee'
      t.references :invited_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.integer :status, default: 0, null: false
      t.datetime :expires_at

      t.timestamps
    end

    add_index :crew_invitations, %i[crew_id user_id status]
    add_index :crew_invitations, %i[user_id status]
  end
end
