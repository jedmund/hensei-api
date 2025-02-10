# frozen_string_literal: true

require 'rails_helper'

# Define a dummy GridSummonBlueprint if it is not already defined.
class GridSummonBlueprint; end unless defined?(GridSummonBlueprint)

RSpec.describe GridSummon, type: :model do
  describe 'associations' do
    it 'belongs to a party' do
      association = described_class.reflect_on_association(:party)
      expect(association).not_to be_nil
      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to a summon' do
      association = described_class.reflect_on_association(:summon)
      expect(association).not_to be_nil
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    let(:party) { create(:party) }
    let(:default_summon) { Summon.find_by!(granblue_id: '2040433000') }

    context 'with valid attributes' do
      subject do
        build(:grid_summon,
              party: party,
              summon: default_summon,
              position: 1,
              uncap_level: 3,
              transcendence_step: 0,
              main: false,
              friend: false,
              quick_summon: false)
      end

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'with missing required attributes' do
      it 'is invalid without a position' do
        grid_summon = build(:grid_summon,
                            party: party,
                            summon: default_summon,
                            position: nil,
                            uncap_level: 3,
                            transcendence_step: 0)
        expect(grid_summon).not_to be_valid
        expect(grid_summon.errors[:position].join).to match(/can't be blank/)
      end

      it 'is invalid without a party' do
        grid_summon = build(:grid_summon,
                            party: nil,
                            summon: default_summon,
                            position: 1,
                            uncap_level: 3,
                            transcendence_step: 0)
        grid_summon.validate
        expect(grid_summon.errors[:party].join).to match(/must exist|can't be blank/)
      end

      it 'is invalid without a summon' do
        grid_summon = build(:grid_summon,
                            party: party,
                            summon: nil,
                            position: 1,
                            uncap_level: 3,
                            transcendence_step: 0)
        expect { grid_summon.valid? }.to raise_error(NoMethodError)
      end
    end

    context 'with non-numeric values' do
      it 'is invalid when uncap_level is non-numeric' do
        grid_summon = build(:grid_summon,
                            party: party,
                            summon: default_summon,
                            position: 1,
                            uncap_level: 'three',
                            transcendence_step: 0)
        expect(grid_summon).not_to be_valid
        expect(grid_summon.errors[:uncap_level]).not_to be_empty
      end

      it 'is invalid when transcendence_step is non-numeric' do
        grid_summon = build(:grid_summon,
                            party: party,
                            summon: default_summon,
                            position: 1,
                            uncap_level: 3,
                            transcendence_step: 'one')
        expect(grid_summon).not_to be_valid
        expect(grid_summon.errors[:transcendence_step]).not_to be_empty
      end
    end

    context 'custom validations based on Summon flags' do
      context 'when the summon does not have FLB flag' do
        let(:summon_without_flb) { default_summon.tap { |s| s.flb = false } }

        it 'is invalid if uncap_level is greater than 3' do
          grid_summon = build(:grid_summon,
                              party: party,
                              summon: summon_without_flb,
                              position: 1,
                              uncap_level: 4,
                              transcendence_step: 0)
          expect(grid_summon).not_to be_valid
          expect(grid_summon.errors[:uncap_level].join).to match(/cannot be greater than 3/)
        end

        it 'is valid if uncap_level is 3 or less' do
          grid_summon = build(:grid_summon,
                              party: party,
                              summon: summon_without_flb,
                              position: 1,
                              uncap_level: 3,
                              transcendence_step: 0)
          expect(grid_summon).to be_valid
        end
      end

      context 'when the summon does not have ULB flag' do
        let(:summon_without_ulb) do
          default_summon.tap do |s|
            s.ulb = false
            s.flb = true
          end
        end

        it 'is invalid if uncap_level is greater than 4' do
          grid_summon = build(:grid_summon,
                              party: party,
                              summon: summon_without_ulb,
                              position: 1,
                              uncap_level: 5,
                              transcendence_step: 0)
          expect(grid_summon).not_to be_valid
          expect(grid_summon.errors[:uncap_level].join).to match(/cannot be greater than 4/)
        end

        it 'is valid if uncap_level is 4 or less' do
          grid_summon = build(:grid_summon,
                              party: party,
                              summon: summon_without_ulb,
                              position: 1,
                              uncap_level: 4,
                              transcendence_step: 0)
          expect(grid_summon).to be_valid
        end
      end

      context 'when the summon does not have transcendence flag' do
        let(:summon_without_transcendence) do
          # Ensure FLB and ULB are true so that only the transcendence rule applies.
          default_summon.tap do |s|
            s.transcendence = false
            s.flb = true
            s.ulb = true
          end
        end

        it 'is invalid if uncap_level is greater than 5' do
          grid_summon = build(:grid_summon,
                              party: party,
                              summon: summon_without_transcendence,
                              position: 1,
                              uncap_level: 6,
                              transcendence_step: 0)
          expect(grid_summon).not_to be_valid
          expect(grid_summon.errors[:uncap_level].join).to match(/cannot be greater than 5/)
        end

        it 'is invalid if transcendence_step is greater than 0' do
          grid_summon = build(:grid_summon,
                              party: party,
                              summon: summon_without_transcendence,
                              position: 1,
                              uncap_level: 5,
                              transcendence_step: 1)
          expect(grid_summon).not_to be_valid
          expect(grid_summon.errors[:transcendence_step].join).to match(/must be 0/)
        end

        it 'is valid if uncap_level is 5 or less and transcendence_step is 0' do
          grid_summon = build(:grid_summon,
                              party: party,
                              summon: summon_without_transcendence,
                              position: 1,
                              uncap_level: 5,
                              transcendence_step: 0)
          expect(grid_summon).to be_valid
        end
      end
    end
  end

  describe 'default values' do
    let(:party) { create(:party) }
    let(:summon) { Summon.find_by!(granblue_id: '2040433000') }
    subject do
      build(:grid_summon,
            party: party,
            summon: summon,
            position: 1,
            uncap_level: 3,
            transcendence_step: 0)
    end

    it 'defaults quick_summon to false' do
      expect(subject.quick_summon).to be_falsey
    end

    it 'defaults main to false' do
      expect(subject.main).to be_falsey
    end

    it 'defaults friend to false' do
      expect(subject.friend).to be_falsey
    end
  end

  describe '#blueprint' do
    it 'returns the GridSummonBlueprint constant' do
      grid_summon = build(:grid_summon)
      expect(grid_summon.blueprint).to eq(GridSummonBlueprint)
    end
  end
end
