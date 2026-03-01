# frozen_string_literal: true

class AddCollectionSourceUserIdToParties < ActiveRecord::Migration[8.0]
  def change
    add_reference :parties, :collection_source_user, type: :uuid, foreign_key: { to_table: :users }, null: true
  end
end
