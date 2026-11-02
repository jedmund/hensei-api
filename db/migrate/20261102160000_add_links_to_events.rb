# frozen_string_literal: true

# External pages for an event, like units have: the gbf.wiki page title, the
# GameWith article id and the Kamigame path under /グラブル/イベント/.
class AddLinksToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :wiki_en, :string
    add_column :events, :gamewith, :string
    add_column :events, :kamigame, :string
  end
end
