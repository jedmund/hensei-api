class AddDisplayNameAndUsernameConstraints < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :display_name, :string
    add_column :users, :username_migrated, :boolean, default: false, null: false

    # Resolve case-insensitive duplicates before adding unique index
    dupes = execute(<<~SQL).to_a
      SELECT lower(username) AS lower_name, array_agg(id ORDER BY created_at ASC) AS ids
      FROM users
      GROUP BY lower(username)
      HAVING count(*) > 1
    SQL

    dupes.each do |row|
      ids = row['ids'].delete('{}').split(',')
      # Skip the first (oldest) — keep their username as-is
      ids[1..].each_with_index do |id, idx|
        suffix = "_#{idx + 1}"
        execute("UPDATE users SET username = username || '#{suffix}' WHERE id = '#{id}'")
        Rails.logger.info "[Migration] Renamed duplicate username for user #{id} with suffix '#{suffix}'"
      end
    end

    add_index :users, 'lower(username)', unique: true, name: 'index_users_on_lower_username'
  end

  def down
    remove_index :users, name: 'index_users_on_lower_username'
    remove_column :users, :username_migrated
    remove_column :users, :display_name
  end
end
