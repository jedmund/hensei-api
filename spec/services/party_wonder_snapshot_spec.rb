# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyWonderSnapshot do
  let(:owner) { create(:user) }
  let(:seal) { create(:wonder, :seal) }
  let(:symbolum) { create(:wonder, :symbolum) }
  let(:exp_wonder) { create(:wonder, :not_battle_relevant) }
  let(:shield) { create(:wonder) }

  before do
    create(:collection_wonder, user: owner, wonder: seal, level: 18, evolution: 2)
    create(:collection_wonder, user: owner, wonder: symbolum, possession: 900, image: '9015_10')
    create(:collection_wonder, user: owner, wonder: exp_wonder)
    create(:collection_wonder, user: owner, wonder: shield, active: false)
  end

  it "copies the creator's active, battle-relevant Wonders" do
    party = create(:party, user: owner)

    expect(party.party_wonders.map(&:wonder)).to contain_exactly(seal, symbolum)
    expect(party.party_wonders.find_by(wonder: seal)).to have_attributes(level: 18, evolution: 2)
    expect(party.party_wonders.find_by(wonder: symbolum)).to have_attributes(possession: 900, image: '9015_10')
  end

  it 'is not changed by later collection edits' do
    party = create(:party, user: owner)
    owner.collection_wonders.find_by(wonder: seal).update!(level: 20, evolution: 3)
    owner.collection_wonders.find_by(wonder: shield).update!(active: true)

    expect(party.party_wonders.reload.find_by(wonder: seal).level).to eq(18)
    expect(party.party_wonders.count).to eq(2)
  end

  it "uses the collection source's Wonders when the team is built for another account" do
    builder = create(:user)
    create(:collection_wonder, user: builder, wonder: shield)

    party = create(:party, user: builder, collection_source_user: owner)

    expect(party.party_wonders.map(&:wonder)).to contain_exactly(seal, symbolum)
  end

  it "copies the source team's Wonders on a remix, not the remixer's" do
    source = create(:party, user: owner)
    source.party_wonders.find_by(wonder: seal).update!(level: 5, evolution: 0)
    remixer = create(:user)
    create(:collection_wonder, user: remixer, wonder: shield)

    remix = source.amoeba_dup
    remix.assign_attributes(user: remixer, source_party: source, remix: true)
    remix.save!

    expect(remix.party_wonders.reload.map(&:wonder)).to contain_exactly(seal, symbolum)
    expect(remix.party_wonders.find_by(wonder: seal).level).to eq(5)
    expect(source.party_wonders.reload.count).to eq(2)
  end

  it 'gives anonymous teams nothing' do
    party = create(:party, user: nil)

    expect(party.party_wonders).to be_empty
  end

  it 'never fails the party create' do
    allow(PartyWonder).to receive(:insert_all!).and_raise(ActiveRecord::StatementInvalid, 'boom')

    party = create(:party, user: owner)

    expect(party).to be_persisted
    expect(party.party_wonders).to be_empty
  end
end
