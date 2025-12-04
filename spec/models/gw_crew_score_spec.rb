require 'rails_helper'

RSpec.describe GwCrewScore, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:crew_gw_participation) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:round) }
    it { is_expected.to validate_presence_of(:crew_score) }
    it { is_expected.to validate_numericality_of(:crew_score).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:opponent_score).is_greater_than_or_equal_to(0).allow_nil }

    describe 'round uniqueness' do
      let!(:participation) { create(:crew_gw_participation) }
      let!(:existing_score) { create(:gw_crew_score, crew_gw_participation: participation, round: :preliminaries) }

      it 'requires unique round per participation' do
        duplicate = build(:gw_crew_score, crew_gw_participation: participation, round: :preliminaries)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:round]).to include('has already been taken')
      end

      it 'allows same round in different participations' do
        other_participation = create(:crew_gw_participation)
        score = build(:gw_crew_score, crew_gw_participation: other_participation, round: :preliminaries)
        expect(score).to be_valid
      end
    end
  end

  describe 'round enum' do
    it 'has expected round values' do
      expect(GwCrewScore.rounds.keys).to contain_exactly(
        'preliminaries', 'interlude', 'finals_day_1', 'finals_day_2', 'finals_day_3', 'finals_day_4'
      )
    end
  end

  describe '#determine_victory callback' do
    let(:participation) { create(:crew_gw_participation) }

    context 'without opponent score' do
      it 'leaves victory nil' do
        score = create(:gw_crew_score, crew_gw_participation: participation, crew_score: 1_000_000, opponent_score: nil)
        expect(score.victory).to be_nil
      end
    end

    context 'with opponent score' do
      it 'sets victory to true when crew wins' do
        score = create(:gw_crew_score, :with_opponent, crew_gw_participation: participation, crew_score: 10_000_000, opponent_score: 5_000_000)
        expect(score.victory).to be true
      end

      it 'sets victory to false when crew loses' do
        score = create(:gw_crew_score, :with_opponent, crew_gw_participation: participation, crew_score: 5_000_000, opponent_score: 10_000_000)
        expect(score.victory).to be false
      end

      it 'sets victory to false on tie' do
        score = create(:gw_crew_score, :with_opponent, crew_gw_participation: participation, crew_score: 5_000_000, opponent_score: 5_000_000)
        expect(score.victory).to be false
      end
    end

    context 'when updating scores' do
      it 'recalculates victory on update' do
        score = create(:gw_crew_score, :victory, crew_gw_participation: participation)
        expect(score.victory).to be true

        score.update!(crew_score: 1_000, opponent_score: 10_000_000)
        expect(score.victory).to be false
      end
    end
  end
end
