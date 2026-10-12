# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SolomonisExpedition, type: :model do
  let(:evoker) { create(:character, :solomonis_evoker) }
  let(:party) { create(:party, :solomonis_run, route_evoker: evoker) }
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
    it { is_expected.to validate_inclusion_of(:kind).in_array(%w[build run]) }

    it 'limits pledge_level to 0..5' do
      expedition.pledge_level = 6
      expect(expedition).not_to be_valid
      expedition.pledge_level = 5
      expect(expedition).to be_valid
    end

    it 'checks outcome, midboss and bosses_defeated values' do
      expedition.assign_attributes(outcome: 'won', midboss: 'raskeid', bosses_defeated: 3)
      expect(expedition).not_to be_valid
      expect(expedition.errors.attribute_names).to include(:outcome, :midboss, :bosses_defeated)
    end

    it 'requires 2 bosses defeated on a cleared run when set' do
      expedition.assign_attributes(outcome: 'cleared', bosses_defeated: 1)
      expect(expedition).not_to be_valid
      expedition.bosses_defeated = nil
      expect(expedition).to be_valid
      expedition.bosses_defeated = 2
      expect(expedition).to be_valid
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

    context 'on a build' do
      let(:party) { create(:party, :solomonis_build, route_evoker: evoker) }

      it 'rejects run-only fields' do
        expedition.assign_attributes(outcome: 'failed', game_report_id: 1, ended_at: Time.current,
                                     stats: { 'battle' => 1 })
        expect(expedition).not_to be_valid
        expect(expedition.errors.attribute_names).to include(:outcome, :game_report_id, :ended_at, :stats)
      end
    end

    it 'cannot become a build while the run has a guidebook' do
      create(:expedition_guide_effect, party: party)
      expedition.kind = 'build'
      expect(expedition).not_to be_valid
      expect(expedition.errors[:kind]).to be_present
    end

    describe 'game_report_id' do
      it 'is unique per user' do
        expedition.update!(game_report_id: 42)
        other_party = create(:party, :solomonis_run, user: party.user)
        other = other_party.solomonis_expedition
        other.game_report_id = 42
        expect(other).not_to be_valid
        expect(other.errors[:game_report_id]).to be_present
      end

      it 'may repeat across users' do
        expedition.update!(game_report_id: 42)
        other = create(:party, :solomonis_run).solomonis_expedition
        expect(other.update(game_report_id: 42)).to be(true)
      end

      it 'is enforced by the database' do
        expedition.update!(game_report_id: 42)
        other = create(:party, :solomonis_run, user: party.user).solomonis_expedition
        expect { other.update_column(:game_report_id, 42) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    describe 'build_party' do
      it 'must be a Solomonis build' do
        expedition.build_party = create(:party)
        expect(expedition).not_to be_valid
        expedition.build_party = create(:party, :solomonis_run)
        expect(expedition).not_to be_valid
        expedition.build_party = create(:party, :solomonis_build)
        expect(expedition).to be_valid
      end

      it 'cannot be the party itself' do
        expedition.build_party_id = party.id
        expect(expedition).not_to be_valid
      end
    end
  end
end
