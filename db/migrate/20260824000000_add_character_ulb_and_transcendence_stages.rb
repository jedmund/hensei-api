# frozen_string_literal: true

class AddCharacterUlbAndTranscendenceStages < ActiveRecord::Migration[8.0]
  LATEST_DATE_INDEX = 'index_characters_on_latest_date'

  def up
    add_column :characters, :ulb, :boolean, default: false, null: false
    add_column :characters, :max_hp_ulb, :integer
    add_column :characters, :max_atk_ulb, :integer
    add_column :characters, :ulb_date, :date
    add_column :characters, :max_transcendence_stage, :integer, default: 0, null: false

    # The original ULB columns were renamed to transcendence columns. Restore
    # special-character ULB data before reserving transcendence for real staged
    # transcendence.
    execute <<~SQL.squish
      UPDATE characters
      SET ulb = TRUE,
          max_hp_ulb = max_hp_transcendence,
          max_atk_ulb = max_atk_transcendence,
          ulb_date = transcendence_date,
          transcendence = FALSE,
          max_hp_transcendence = NULL,
          max_atk_transcendence = NULL,
          transcendence_date = NULL,
          max_transcendence_stage = 0
      WHERE special = TRUE AND transcendence = TRUE
    SQL

    execute <<~SQL.squish
      UPDATE characters
      SET max_transcendence_stage = 5
      WHERE special = FALSE AND transcendence = TRUE
    SQL

    execute <<~SQL.squish
      UPDATE grid_characters
      SET transcendence_step = 0
      WHERE character_id IN (SELECT id FROM characters WHERE ulb = TRUE)
    SQL

    execute <<~SQL.squish
      UPDATE collection_characters
      SET transcendence_step = 0
      WHERE character_id IN (SELECT id FROM characters WHERE ulb = TRUE)
    SQL

    rebuild_latest_date('greatest(release_date, flb_date, ulb_date, transcendence_date)')
  end

  def down
    execute <<~SQL.squish
      UPDATE characters
      SET transcendence = TRUE,
          max_hp_transcendence = max_hp_ulb,
          max_atk_transcendence = max_atk_ulb,
          transcendence_date = ulb_date
      WHERE special = TRUE AND ulb = TRUE
    SQL

    rebuild_latest_date('greatest(release_date, flb_date, transcendence_date)')

    remove_column :characters, :max_transcendence_stage
    remove_column :characters, :ulb_date
    remove_column :characters, :max_atk_ulb
    remove_column :characters, :max_hp_ulb
    remove_column :characters, :ulb
  end

  private

  def rebuild_latest_date(expression)
    remove_index :characters, name: LATEST_DATE_INDEX, if_exists: true
    remove_column :characters, :latest_date, if_exists: true

    execute <<~SQL
      ALTER TABLE characters
      ADD COLUMN latest_date date GENERATED ALWAYS AS (#{expression}) STORED;
    SQL

    add_index :characters, [:latest_date, :id],
              order: { latest_date: :desc, id: :asc },
              name: LATEST_DATE_INDEX
  end
end
