# frozen_string_literal: true

class CreateUserEditKeys < ActiveRecord::Migration[7.1]
  def change
    create_table :user_edit_keys, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :edit_key, null: false
      t.string :shortcode, null: false
      t.datetime :created_at, null: false
    end

    add_index :user_edit_keys, %i[user_id edit_key], unique: true
  end
end
