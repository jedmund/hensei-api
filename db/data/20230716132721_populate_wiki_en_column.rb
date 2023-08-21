# frozen_string_literal: true

class PopulateWikiEnColumn < ActiveRecord::Migration[7.0]
  def up
    Character.all.each do |c|
      c.wiki_en = c.name_en
      c.save
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
