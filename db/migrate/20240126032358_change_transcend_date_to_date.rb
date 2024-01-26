class ChangeTranscendDateToDate < ActiveRecord::Migration[7.0]
  def change
    remove_column :weapons, :transcendence_date, :datetime
    add_column :weapons, :transcendence_date, :date
  end
end
