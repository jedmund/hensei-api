class CreateDifficultyConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :difficulty_configs, id: :uuid do |t|
      t.integer :ruleset_version, null: false, default: 1
      t.timestamps
    end
  end
end
