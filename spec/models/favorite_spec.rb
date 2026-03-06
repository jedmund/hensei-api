# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Favorite, type: :model do
  describe 'associations' do
    it 'belongs to a user' do
      favorite = create(:favorite)
      expect(favorite.user).to be_a(User)
      expect(favorite.user_id).to be_present
    end

    it 'belongs to a party' do
      favorite = create(:favorite)
      expect(favorite.party).to be_a(Party)
      expect(favorite.party_id).to be_present
    end
  end

  it 'creates a valid favorite' do
    favorite = create(:favorite)
    expect(favorite).to be_persisted
    expect(favorite.user).to be_present
    expect(favorite.party_id).to be_present
  end

  it 'destroying a favorite does not destroy the party' do
    favorite = create(:favorite)
    party = favorite.party
    favorite.destroy
    expect(party.reload).to be_persisted
  end
end
