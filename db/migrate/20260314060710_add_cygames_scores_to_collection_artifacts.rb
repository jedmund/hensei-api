class AddCygamesScoresToCollectionArtifacts < ActiveRecord::Migration[8.0]
  def change
    add_column :collection_artifacts, :attack_score, :integer
    add_column :collection_artifacts, :defense_score, :integer
    add_column :collection_artifacts, :special_score, :integer
    add_column :collection_artifacts, :total_score, :integer
  end
end
