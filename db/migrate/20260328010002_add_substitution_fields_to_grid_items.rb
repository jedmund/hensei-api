# frozen_string_literal: true

class AddSubstitutionFieldsToGridItems < ActiveRecord::Migration[8.0]
  def change
    %i[grid_characters grid_weapons grid_summons].each do |table|
      change_table table do |t|
        t.boolean :is_substitute, null: false, default: false
        t.references :role, type: :uuid, foreign_key: true
        t.text :substitution_note
      end
    end
  end
end
