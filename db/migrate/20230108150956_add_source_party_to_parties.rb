class AddSourcePartyToParties < ActiveRecord::Migration[7.0]
  def change
    change_table(:parties) do |t|
      t.references :source_party, type: :uuid, foreign_key: { to_table: 'parties' }
    end
  end
end
