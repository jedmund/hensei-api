# frozen_string_literal: true

class CreateRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :roles, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :name_en, null: false
      t.string :name_jp
      t.string :slot_type, null: false
      t.integer :sort_order, default: 0

      t.timestamps
    end

    add_index :roles, :slot_type
  end
end
