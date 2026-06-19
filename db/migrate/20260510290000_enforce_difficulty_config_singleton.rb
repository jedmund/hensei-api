class EnforceDifficultyConfigSingleton < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = 'index_difficulty_configs_singleton'.freeze

  def up
    # DifficultyConfig is a singleton. A partial unique index on the constant
    # expression (true) lets PostgreSQL reject a second row even when two
    # callers race past `DifficultyConfig.first` and both reach `create!`.
    execute <<~SQL.squish
      CREATE UNIQUE INDEX IF NOT EXISTS #{INDEX_NAME}
        ON difficulty_configs ((true))
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS #{INDEX_NAME}"
  end
end
