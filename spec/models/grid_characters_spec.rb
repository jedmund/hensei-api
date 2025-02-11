# frozen_string_literal: true
# spec/models/grid_character_spec.rb
#
# This spec verifies the GridCharacter model’s associations, validations,
# and callbacks. It uses FactoryBot for object creation, shoulda-matchers
# for association/validation shortcuts, and a custom matcher (have_error_on)
# for checking that error messages include specific phrases.
#
# In this version we use canonical data loaded from CSV (via our CSV loader)
# rather than generating new Character and Awakening records.
#
require 'rails_helper'

RSpec.describe GridCharacter, type: :model do
  # Association tests using shoulda-matchers.
  it { is_expected.to belong_to(:character) }
  it { is_expected.to belong_to(:party) }
  it { is_expected.to belong_to(:awakening).optional }

  # Use the canonical "Balanced" awakening already loaded from CSV.
  before(:all) do
    @balanced_awakening = Awakening.find_by!(slug: 'character-balanced')
  end

  # Use canonical records loaded from CSV for our character.
  let(:party) { create(:party) }
  let(:character) do
    # Assume canonical test data has been loaded.
    Character.find_by!(granblue_id: '3040087000')
  end

  let(:valid_attributes) do
    {
      party: party,
      character: character,
      position: 0,
      uncap_level: 3,
      transcendence_step: 0
    }
  end

  describe 'Validations and Associations' do
    context 'with valid attributes' do
      subject { build(:grid_character, valid_attributes) }
      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'without a party' do
      subject { build(:grid_character, valid_attributes.merge(party: nil)) }
      it 'is invalid' do
        subject.valid?
        expect(subject.errors[:party]).to include("can't be blank")
      end
    end
  end

  describe 'Callbacks' do
    context 'before_validation :apply_new_rings' do
      it 'sets the ring attributes when new_rings is provided' do
        grid_char = build(
          :grid_character,
          valid_attributes.merge(new_rings: [
            { 'modifier' => '1', 'strength' => 300 },
            { 'modifier' => '2', 'strength' => 150 }
          ])
        )
        grid_char.valid? # triggers the before_validation callback
        expect(grid_char.ring1).to eq({ 'modifier' => '1', 'strength' => 300 })
        expect(grid_char.ring2).to eq({ 'modifier' => '2', 'strength' => 150 })
        # The rings array is padded to have exactly four entries.
        expect(grid_char.ring3).to eq({ 'modifier' => nil, 'strength' => nil })
        expect(grid_char.ring4).to eq({ 'modifier' => nil, 'strength' => nil })
      end
    end

    context 'before_validation :apply_new_awakening' do
      it 'sets awakening_id and awakening_level when new_awakening is provided using a canonical awakening' do
        # Use an existing awakening from the CSV data.
        canonical_awakening = Awakening.find_by!(slug: 'character-def')
        new_awakening = { id: canonical_awakening.id, level: '5' }
        grid_char = build(:grid_character, valid_attributes.merge(new_awakening: new_awakening))
        grid_char.valid?
        expect(grid_char.awakening_id).to eq(canonical_awakening.id)
        expect(grid_char.awakening_level).to eq(5)
      end
    end

    context 'before_save :add_awakening' do
      it 'sets the awakening to the balanced canonical awakening if none is provided' do
        grid_char = build(:grid_character, valid_attributes.merge(awakening: nil))
        grid_char.save!
        expect(grid_char.awakening).to eq(@balanced_awakening)
      end

      it 'does not override an existing awakening' do
        existing_awakening = Awakening.find_by!(slug: 'character-def')
        grid_char = build(:grid_character, valid_attributes.merge(awakening: existing_awakening))
        grid_char.save!
        expect(grid_char.awakening).to eq(existing_awakening)
      end
    end
  end

  describe 'Update Validations (on :update)' do
    before do
      # Persist a valid GridCharacter record.
      @grid_char = create(:grid_character, valid_attributes)
    end

    context 'validate_awakening_level' do
      it 'adds an error if awakening_level is below 1' do
        @grid_char.awakening_level = 0
        @grid_char.valid?(:update)
        expect(@grid_char.errors[:awakening]).to include('awakening level too low')
      end

      it 'adds an error if awakening_level is above 9' do
        @grid_char.awakening_level = 10
        @grid_char.valid?(:update)
        expect(@grid_char.errors[:awakening]).to include('awakening level too high')
      end
    end

    context 'transcendence validation' do
      it 'adds an error if transcendence_step is positive but character.ulb is false' do
        @grid_char.character.update!(ulb: false)
        @grid_char.transcendence_step = 1
        @grid_char.valid?(:update)
        expect(@grid_char.errors[:transcendence_step]).to include('character has no transcendence')
      end

      it 'adds an error if transcendence_step is greater than 5 when character.ulb is true' do
        @grid_char.character.update!(ulb: true)
        @grid_char.transcendence_step = 6
        @grid_char.valid?(:update)
        expect(@grid_char.errors[:transcendence_step]).to include('transcendence step too high')
      end

      it 'adds an error if transcendence_step is negative when character.ulb is true' do
        @grid_char.character.update!(ulb: true)
        @grid_char.transcendence_step = -1
        @grid_char.valid?(:update)
        expect(@grid_char.errors[:transcendence_step]).to include('transcendence step too low')
      end
    end

    context 'over_mastery_attack_matches_hp validation' do
      it 'adds an error if ring1 and ring2 values are inconsistent' do
        @grid_char.ring1 = { modifier: '1', strength: 300 }
        # Expected: ring2 strength should be half of 300 (i.e. 150)
        @grid_char.ring2 = { modifier: '2', strength: 100 }
        @grid_char.valid?(:update)
        expect(@grid_char.errors[:over_mastery]).to include('over mastery attack and hp values do not match')
      end

      it 'is valid if ring2 strength equals half of ring1 strength' do
        @grid_char.ring1 = { modifier: '1', strength: 300 }
        @grid_char.ring2 = { modifier: '2', strength: 150 }
        @grid_char.valid?(:update)
        expect(@grid_char.errors[:over_mastery]).to be_empty
      end
    end
  end
end
