class AddUpdatesTable < ActiveRecord::Migration[7.0]
  def change
    create_table :app_updates, id: false do |t|
      t.string :update_type, null: false
      t.datetime :updated_at, null: false, unique: true, primary_key: true
    end
  end
end
