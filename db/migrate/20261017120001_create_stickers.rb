# frozen_string_literal: true

# Stickers are the catalogue members pick from to recommend a team. Editors
# manage the catalogue; a sticker that has been given is retired with `active`
# rather than deleted.
class CreateStickers < ActiveRecord::Migration[8.1]
  def change
    create_table :stickers, id: :uuid do |t|
      t.string :slug, null: false
      t.string :meaning_en, null: false
      t.string :meaning_jp
      t.string :image_key
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :stickers, :slug, unique: true
    add_index :stickers, %i[active position]
  end
end
