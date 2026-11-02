# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sticker, type: :model do
  describe 'image keys' do
    it 'accepts its own uploads and shared library images' do
      sticker = build(:sticker, image_key: 'icons/stickers/cleared.png', image_key_jp: 'icons/stickers/stamp12.ja.webp')
      expect(sticker).to be_valid
    end

    it 'accepts no image' do
      expect(build(:sticker, image_key: nil, image_key_jp: nil)).to be_valid
    end

    it 'rejects keys outside the sticker prefix or in other formats' do
      ['weapons/x.png', 'icons/stickers/../x.png', 'icons/stickers/x.jpg', 'icons/stickers/', ''].each do |key|
        sticker = build(:sticker, image_key: key, image_key_jp: key)
        expect(sticker).not_to be_valid, key
        expect(sticker.errors).to include(:image_key, :image_key_jp)
      end
    end
  end

  it 'keeps its slug once created' do
    sticker = create(:sticker, slug: 'cleared')
    sticker.slug = 'renamed'
    expect(sticker).not_to be_valid
    expect(sticker.errors).to include(:slug)
  end

  it 'requires active to be true or false' do
    expect(build(:sticker, active: nil)).not_to be_valid
  end
end
