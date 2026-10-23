# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SolomonisExpedition, type: :model do
  let(:evoker) { create(:character, :solomonis_evoker) }
  let(:party) { create(:party, :solomonis, route_evoker: evoker) }
  let(:expedition) { party.solomonis_expedition }

  it 'is valid as built by the factory' do
    expect(create(:solomonis_expedition)).to be_persisted
    expect(create(:solomonis_expedition, :cleared)).to be_persisted
  end

  it 'copies the party owner into user_id' do
    expect(expedition.user_id).to eq(party.user_id)
  end

  it 'follows a change of party owner' do
    other = create(:user)
    party.update!(user: other)
    expect(expedition.reload.user_id).to eq(other.id)
  end

  describe 'validations' do
    it 'limits pledge_level to 0..5' do
      expedition.pledge_level = 6
      expect(expedition).not_to be_valid
      expedition.pledge_level = 5
      expect(expedition).to be_valid
    end

    it 'accepts the three outcomes or none' do
      [nil, 'miasma_1', 'miasma_2', 'cleared'].each do |outcome|
        expedition.outcome = outcome
        expect(expedition).to be_valid
      end
      expedition.outcome = 'failed'
      expect(expedition).not_to be_valid
      expect(expedition.errors[:outcome]).to be_present
    end

    it 'checks outcome in the database too' do
      expect { expedition.update_column(:outcome, 'failed') }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'maps bosses defeated to an outcome' do
      expect((0..3).map { |n| described_class.outcome_for_bosses(n) }).to eq(['miasma_1', 'miasma_2', 'cleared', nil])
      expect(described_class.outcome_for_bosses(-1)).to be_nil
    end

    it 'accepts known stats keys with non-negative integers only' do
      expedition.stats = { 'battle' => 3, 'points_earned' => 10 }
      expect(expedition).to be_valid
      expedition.stats = { 'battle' => -1 }
      expect(expedition).not_to be_valid
      expedition.stats = { 'gold' => 1 }
      expect(expedition).not_to be_valid
      expedition.stats = { 'battle' => '3' }
      expect(expedition).not_to be_valid
    end

    it 'requires a route-eligible Evoker' do
      expedition.route_evoker = create(:character)
      expect(expedition).not_to be_valid
      expect(expedition.errors[:route_evoker]).to be_present
    end

    it "rejects a route Evoker outside the party's zone when saved on its own" do
      expedition.route_evoker = create(:character, :solomonis_evoker)
      expect(expedition).not_to be_valid
      expect(expedition.errors[:route_evoker].join).to include('zone')
    end

    describe 'game_report_id' do
      it 'is unique per user' do
        expedition.update!(game_report_id: 42)
        other_party = create(:party, :solomonis, user: party.user)
        other = other_party.solomonis_expedition
        other.game_report_id = 42
        expect(other).not_to be_valid
        expect(other.errors[:game_report_id]).to be_present
      end

      it 'may repeat across users' do
        expedition.update!(game_report_id: 42)
        other = create(:party, :solomonis).solomonis_expedition
        expect(other.update(game_report_id: 42)).to be(true)
      end

      it 'is enforced by the database' do
        expedition.update!(game_report_id: 42)
        other = create(:party, :solomonis, user: party.user).solomonis_expedition
        expect { other.update_column(:game_report_id, 42) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end
end
