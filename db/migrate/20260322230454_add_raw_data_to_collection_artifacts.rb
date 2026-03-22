# frozen_string_literal: true

class AddRawDataToCollectionArtifacts < ActiveRecord::Migration[7.1]
  def change
    add_column :collection_artifacts, :raw_data, :jsonb
  end
end
