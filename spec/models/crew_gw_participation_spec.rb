require 'rails_helper'

RSpec.describe CrewGwParticipation, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:crew) }
    it { is_expected.to belong_to(:gw_event) }
    it { is_expected.to have_many(:gw_crew_scores).dependent(:destroy) }
    it { is_expected.to have_many(:gw_individual_scores).dependent(:destroy) }
  end

  describe 'validations' do
    let!(:crew) { create(:crew) }
    let!(:gw_event) { create(:gw_event) }
    let!(:existing_participation) { create(:crew_gw_participation, crew: crew, gw_event: gw_event) }

    it 'requires unique crew and gw_event combination' do
      duplicate = build(:crew_gw_participation, crew: crew, gw_event: gw_event)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:crew_id]).to include('is already participating in this event')
    end

    it 'allows same crew in different events' do
      other_event = create(:gw_event)
      participation = build(:crew_gw_participation, crew: crew, gw_event: other_event)
      expect(participation).to be_valid
    end

    it 'allows different crews in same event' do
      other_crew = create(:crew)
      participation = build(:crew_gw_participation, crew: other_crew, gw_event: gw_event)
      expect(participation).to be_valid
    end
  end

  describe '#total_crew_score' do
    let(:participation) { create(:crew_gw_participation) }

    context 'with no scores' do
      it 'returns 0' do
        expect(participation.total_crew_score).to eq(0)
      end
    end

    context 'with scores' do
      before do
        create(:gw_crew_score, crew_gw_participation: participation, round: :preliminaries, crew_score: 1_000_000)
        create(:gw_crew_score, crew_gw_participation: participation, round: :finals_day_1, crew_score: 2_000_000)
      end

      it 'returns the sum of all crew scores' do
        expect(participation.total_crew_score).to eq(3_000_000)
      end
    end
  end

  describe '#wins_count and #losses_count' do
    let(:participation) { create(:crew_gw_participation) }

    context 'with no battles' do
      it 'returns 0 for both' do
        expect(participation.wins_count).to eq(0)
        expect(participation.losses_count).to eq(0)
      end
    end

    context 'with battles' do
      before do
        create(:gw_crew_score, :victory, crew_gw_participation: participation, round: :finals_day_1)
        create(:gw_crew_score, :victory, crew_gw_participation: participation, round: :finals_day_2)
        create(:gw_crew_score, :defeat, crew_gw_participation: participation, round: :finals_day_3)
      end

      it 'returns correct win count' do
        expect(participation.wins_count).to eq(2)
      end

      it 'returns correct loss count' do
        expect(participation.losses_count).to eq(1)
      end
    end
  end
end
