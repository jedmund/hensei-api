class AddAccessoryIdToParty < ActiveRecord::Migration[7.0]
  def change
    change_table(:parties) do |t|
      t.references :accessory, type: :uuid, foreign_key: { to_table: 'job_accessories' }
    end
  end
end
