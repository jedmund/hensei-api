# frozen_string_literal: true

# The game's chat stickers (stamps), from gbf.wiki's Stickers page, which
# editors pick from when adding a sticker instead of uploading images. The
# list is data/sticker_library.json; the images live in the bucket at each
# entry's image_key (and image_key_jp, the Japanese version, when there is
# one), shared by every sticker made from them.
module StickerLibrary
  Entry = Data.define(:id, :label, :section, :group, :image_key, :image_key_jp)

  PATH = Rails.root.join('data/sticker_library.json')

  module_function

  def all
    @all ||= JSON.parse(PATH.read, symbolize_names: true).map { |row| Entry.new(**row) }.freeze
  end

  def find(id)
    by_id[id.to_i]
  end

  def by_id
    @by_id ||= all.index_by(&:id)
  end
end
