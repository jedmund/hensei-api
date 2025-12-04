# frozen_string_literal: true

class AddJoinedAtToCrewMembershipsAndPhantomPlayers < ActiveRecord::Migration[8.0]
  def up
    add_column :crew_memberships, :joined_at, :datetime
    add_column :phantom_players, :joined_at, :datetime

    # Backfill joined_at from created_at for existing records
    execute <<-SQL
      UPDATE crew_memberships SET joined_at = created_at WHERE joined_at IS NULL
    SQL
    execute <<-SQL
      UPDATE phantom_players SET joined_at = created_at WHERE joined_at IS NULL
    SQL
  end

  def down
    remove_column :crew_memberships, :joined_at
    remove_column :phantom_players, :joined_at
  end
end
