# frozen_string_literal: true

class AddWikiRawJpToCharactersAndSummons < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :wiki_raw_jp, :text, comment: 'Raw HTML from gbf-wiki.com (Japanese)'
    add_column :summons, :wiki_raw_jp, :text, comment: 'Raw HTML from gbf-wiki.com (Japanese)'
  end
end
