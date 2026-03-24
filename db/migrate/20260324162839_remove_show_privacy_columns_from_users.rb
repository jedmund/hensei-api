class RemoveShowPrivacyColumnsFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :show_granblue_id, :boolean, default: false, null: false
    remove_column :users, :show_wiki_profile, :boolean, default: false, null: false
    remove_column :users, :show_youtube, :boolean, default: false, null: false
  end
end
