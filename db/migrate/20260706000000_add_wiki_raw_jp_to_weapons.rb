# frozen_string_literal: true

class AddWikiRawJpToWeapons < ActiveRecord::Migration[8.0]
  def change
    add_column :weapons, :wiki_raw_jp, :text, comment: 'Raw HTML from gbf-wiki.com (Japanese)'
  end
end
