class EnablePgStatements < ActiveRecord::Migration[8.0]
  def up
    execute 'CREATE EXTENSION IF NOT EXISTS pg_stat_statements;'
  end

  def down
    execute 'DROP EXTENSION IF EXISTS pg_stat_statements;'
  end
end
