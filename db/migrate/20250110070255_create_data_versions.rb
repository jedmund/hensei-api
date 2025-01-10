# frozen_string_literal: true

class CreateDataVersions < ActiveRecord::Migration[7.0]
  def change
    create_table :data_versions, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :filename, null: false
      t.datetime :imported_at, null: false
      t.index :filename, unique: true
    end
  end
end
