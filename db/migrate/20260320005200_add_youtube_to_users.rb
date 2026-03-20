# frozen_string_literal: true

class AddYoutubeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :youtube, :string
    add_column :users, :show_youtube, :boolean, default: false, null: false
  end
end
