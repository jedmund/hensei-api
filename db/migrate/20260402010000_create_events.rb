class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events, id: :uuid do |t|
      t.string :name, null: false
      t.integer :event_type, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.integer :element
      t.string :banner_image
      t.timestamps
    end

    add_index :events, :event_type
    add_index :events, :start_time
    add_index :events, [:start_time, :end_time]
  end
end
