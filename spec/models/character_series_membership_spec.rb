# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSeriesMembership, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:character) }
    it { is_expected.to belong_to(:character_series) }
  end

  describe 'validations' do
    it 'prevents duplicate character-series pairs' do
      membership = create(:character_series_membership)
      duplicate = build(:character_series_membership,
                        character: membership.character,
                        character_series: membership.character_series)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:character_id]).to include('has already been taken')
    end

    it 'allows the same character in different series' do
      character = create(:character)
      series_a = create(:character_series)
      series_b = create(:character_series)
      create(:character_series_membership, character: character, character_series: series_a)
      membership = build(:character_series_membership, character: character, character_series: series_b)
      expect(membership).to be_valid
    end
  end
end
