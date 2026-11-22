# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::PartyBlueprint do
  it 'sends the clear time and button counts in the list view for card pills' do
    party = create(:party, clear_time: 21, button_count: 0, chain_count: 1, summon_count: 2, turn_count: 3)

    hash = described_class.render_as_hash(party, view: :list)

    expect(hash).to include(clear_time: 21, button_count: 0, chain_count: 1, summon_count: 2)
    expect(hash).not_to have_key(:turn_count)
  end

  it "sends the raid group's section in the list view so cards can tell event teams apart" do
    party = create(:party, raid: create(:raid, group: create(:raid_group, section: 2)))

    hash = described_class.render_as_hash(party, view: :list)

    expect(hash.dig(:raid, :group, :section)).to eq(2)
  end
end
