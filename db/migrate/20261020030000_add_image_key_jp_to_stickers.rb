# frozen_string_literal: true

# A sticker's Japanese image (the stamp with its Japanese caption), shown to
# viewers using Japanese. Null falls back to `image_key`.
class AddImageKeyJpToStickers < ActiveRecord::Migration[8.1]
  def change
    add_column :stickers, :image_key_jp, :string
  end
end
