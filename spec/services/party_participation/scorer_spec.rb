# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyParticipation::Scorer do
  let(:now) { Time.current }
  let(:owner) { create(:user) }
  let(:party) { create(:party, user: owner, visibility: 1) }
  let(:sticker) { create(:sticker) }

  def score(**)
    described_class.call([party.id], as_of: now, **)[party.id]
  end

  def give(by:, at: now)
    create(:party_sticker, party: party, sticker: sticker, user: by, created_at: at)
  end

  it 'counts a fresh sticker from a trusted giver as 1' do
    give(by: trusted_user)
    expect(score).to be_within(0.001).of(1.0)
  end

  it 'halves a sticker after one half-life' do
    give(by: trusted_user, at: now - 7.days)
    expect(score).to be_within(0.001).of(0.5)
  end

  it 'honours a custom half-life' do
    give(by: trusted_user, at: now - 2.days)
    expect(score(half_life: 2.days)).to be_within(0.001).of(0.5)
  end

  it 'downweights givers whose account was new when they gave the sticker' do
    young = create(:user, created_at: now - 3.days)
    create(:party, user: young, visibility: 1)
    give(by: young)
    expect(score).to be_within(0.001).of(described_class::LOW_TRUST_WEIGHT)
  end

  it 'downweights givers with no public parties' do
    lurker = create(:user, created_at: now - 60.days)
    create(:party, user: lurker, visibility: 3)
    give(by: lurker)
    expect(score).to be_within(0.001).of(described_class::LOW_TRUST_WEIGHT)
  end

  it 'counts retired stickers' do
    give(by: trusted_user)
    sticker.update!(active: false)
    expect(score).to be_within(0.001).of(1.0)
  end

  it 'only counts activity inside the window' do
    give(by: trusted_user, at: now - 10.days)
    give(by: trusted_user, at: now - 1.day)
    expect(score(since: now - 5.days, half_life: 100.years)).to be_within(0.001).of(1.0)
    expect(score(as_of: now - 5.days, half_life: 100.years)).to be_within(0.001).of(1.0)
  end

  it 'adds remixes by other users, but not anonymous or self remixes' do
    create(:party, source_party: party, user: create(:user), remix: true)
    create(:party, source_party: party, user: nil, remix: true)
    create(:party, source_party: party, user: owner, remix: true)
    expect(score).to be_within(0.001).of(described_class::REMIX_WEIGHT)
  end

  it "adds favorites by other users, but not the owner's" do
    create(:favorite, party: party, user: create(:user))
    create(:favorite, party: party, user: owner)
    expect(score).to be_within(0.001).of(described_class::FAVORITE_WEIGHT)
  end

  it 'omits parties with no activity' do
    expect(described_class.call([party.id])).to eq({})
    expect(described_class.call([])).to eq({})
  end

  it 'accepts a relation of ids' do
    give(by: trusted_user)
    result = described_class.call(Party.where(id: party.id).select(:id), as_of: now)
    expect(result[party.id]).to be_within(0.001).of(1.0)
  end
end
