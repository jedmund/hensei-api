# frozen_string_literal: true

# Stickers made from a library stamp copy its image keys when they're made,
# so a Japanese image added to the library later never reaches them. Stamps
# 368–373 and 385 gained Japanese images (uploaded to the bucket by hand and
# added to data/sticker_library.json); this gives stickers made from any
# library stamp its Japanese image where they have none.
class BackfillStickerLibraryJapaneseImages < ActiveRecord::Migration[8.1]
  def up
    StickerLibrary.all.select(&:image_key_jp).each do |entry|
      # One by one, so each bumps its image version and clears the catalogue cache
      Sticker.where(image_key: entry.image_key, image_key_jp: nil).find_each do |sticker|
        sticker.update!(image_key_jp: entry.image_key_jp)
      end
    end
  end

  def down
    # Nothing to undo: the stickers only gained an image their stamp has
  end
end
