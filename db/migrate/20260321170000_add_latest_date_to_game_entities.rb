# frozen_string_literal: true

class AddLatestDateToGameEntities < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      ALTER TABLE characters
      ADD COLUMN latest_date date GENERATED ALWAYS AS (
        greatest(release_date, flb_date, transcendence_date)
      ) STORED;
    SQL

    execute <<-SQL
      ALTER TABLE weapons
      ADD COLUMN latest_date date GENERATED ALWAYS AS (
        greatest(release_date, flb_date, ulb_date, transcendence_date)
      ) STORED;
    SQL

    execute <<-SQL
      ALTER TABLE summons
      ADD COLUMN latest_date date GENERATED ALWAYS AS (
        greatest(release_date, flb_date, ulb_date, transcendence_date)
      ) STORED;
    SQL

    add_index :characters, [:latest_date, :id], order: { latest_date: :desc, id: :asc }, name: 'index_characters_on_latest_date'
    add_index :weapons, [:latest_date, :id], order: { latest_date: :desc, id: :asc }, name: 'index_weapons_on_latest_date'
    add_index :summons, [:latest_date, :id], order: { latest_date: :desc, id: :asc }, name: 'index_summons_on_latest_date'
  end

  def down
    remove_column :characters, :latest_date
    remove_column :weapons, :latest_date
    remove_column :summons, :latest_date
  end
end
