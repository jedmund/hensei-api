# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Favorite, type: :model do
  it 'creates a valid favorite' do
    favorite = create(:favorite)
    expect(favorite).to be_persisted
    expect(favorite.user).to be_present
    expect(favorite.party_id).to be_present
  end
end
