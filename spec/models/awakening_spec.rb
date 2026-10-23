# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Awakening, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:weapon_awakenings).with_foreign_key(:awakening_id) }
    it { is_expected.to have_many(:weapons).through(:weapon_awakenings) }
  end

  describe 'slug' do
    it 'accepts the existing awakening slugs' do
      %w[character-atk character-balanced weapon-ca weapon-special].each do |slug|
        expect(build(:awakening, slug: slug)).to be_valid
      end
    end

    it 'rejects slugs that are not lowercase words joined by hyphens' do
      ['', 'Weapon-ATK', 'weapon_atk', '../weapon-atk', 'weapon atk', 'weapon-', 'a' * 65].each do |slug|
        expect(build(:awakening, slug: slug)).not_to be_valid, "expected #{slug.inspect} to be invalid"
      end
    end
  end

  describe '#image_formats' do
    it 'takes a JPEG for character awakenings and a PNG for the rest' do
      expect(build(:awakening, slug: 'character-atk').image_formats).to eq(%w[JPEG])
      expect(build(:awakening, slug: 'weapon-atk').image_formats).to eq(%w[PNG])
    end
  end
end
