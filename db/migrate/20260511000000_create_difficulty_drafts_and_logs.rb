class CreateDifficultyDraftsAndLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :difficulty_drafts, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :target_type, null: false
      t.uuid :target_id
      t.string :operation, null: false
      t.jsonb :attributes_payload, null: false, default: {}
      t.timestamps
    end

    # One pending update / destroy per (user, target). Unique by partial index
    # so multiple `create` drafts (target_id IS NULL) can coexist.
    add_index :difficulty_drafts,
              %i[user_id target_type target_id],
              unique: true,
              where: 'target_id IS NOT NULL',
              name: 'index_difficulty_drafts_per_target'
    add_index :difficulty_drafts, %i[user_id target_type]

    create_table :difficulty_change_logs, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.text :note
      t.jsonb :changes_payload, null: false, default: {}
      t.integer :ruleset_version_after
      t.datetime :committed_at, null: false
      t.timestamps
    end

    add_index :difficulty_change_logs, :committed_at
  end
end
