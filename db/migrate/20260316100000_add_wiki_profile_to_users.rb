# frozen_string_literal: true

class AddWikiProfileToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :wiki_profile, :string
    add_column :users, :show_wiki_profile, :boolean, default: false, null: false
  end
end
