require 'rails_helper'

RSpec.describe GwIndividualScore, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:crew_gw_participation) }
    it { is_expected.to belong_to(:crew_membership).optional }
    it { is_expected.to belong_to(:recorded_by).class_name('User') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:round) }
    it { is_expected.to validate_numericality_of(:score).is_greater_than_or_equal_to(0) }

    describe 'round uniqueness per player' do
      let!(:participation) { create(:crew_gw_participation) }
      let!(:membership) { create(:crew_membership, crew: participation.crew) }
      let!(:existing_score) do
        create(:gw_individual_score,
               crew_gw_participation: participation,
               crew_membership: membership,
               round: :preliminaries)
      end

      it 'requires unique round per membership and participation' do
        duplicate = build(:gw_individual_score,
                          crew_gw_participation: participation,
                          crew_membership: membership,
                          round: :preliminaries)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:crew_membership_id]).to include('already has a score for this round')
      end

      it 'allows same round for different members' do
        other_membership = create(:crew_membership, crew: participation.crew)
        score = build(:gw_individual_score,
                      crew_gw_participation: participation,
                      crew_membership: other_membership,
                      round: :preliminaries)
        expect(score).to be_valid
      end

      it 'allows same member in different rounds' do
        score = build(:gw_individual_score,
                      crew_gw_participation: participation,
                      crew_membership: membership,
                      round: :finals_day_1)
        expect(score).to be_valid
      end
    end
  end

  describe 'round enum' do
    it 'has expected round values' do
      expect(GwIndividualScore.rounds.keys).to contain_exactly(
        'preliminaries', 'interlude', 'finals_day_1', 'finals_day_2', 'finals_day_3', 'finals_day_4'
      )
    end
  end

  describe 'is_cumulative flag' do
    let(:participation) { create(:crew_gw_participation) }
    let(:membership) { create(:crew_membership, crew: participation.crew) }

    it 'defaults to false from factory' do
      score = create(:gw_individual_score,
                     crew_gw_participation: participation,
                     crew_membership: membership)
      expect(score.is_cumulative).to be false
    end

    it 'can be set to true' do
      score = create(:gw_individual_score,
                     crew_gw_participation: participation,
                     crew_membership: membership,
                     is_cumulative: true)
      expect(score.is_cumulative).to be true
    end
  end

  describe 'recorded_by association' do
    let(:participation) { create(:crew_gw_participation) }
    let(:membership) { create(:crew_membership, crew: participation.crew) }
    let(:recorder) { create(:user) }

    it 'tracks who recorded the score' do
      score = create(:gw_individual_score,
                     crew_gw_participation: participation,
                     crew_membership: membership,
                     recorded_by: recorder)
      expect(score.recorded_by).to eq(recorder)
    end
  end
end
