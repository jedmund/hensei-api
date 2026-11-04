# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Processors::CharacterProcessor, type: :model do
  subject!(:character_processor) { described_class.new(party, deck_data, language: 'en') }

  let(:party) { create(:party) }
  let(:deck_data) do
    file_path = Rails.root.join("spec/fixtures/deck_sample2.json")
    JSON.parse(File.read(file_path))
  end

  context 'with valid character data' do
    it 'creates the correct number of GridCharacter records' do
      expect { character_processor.process }.to change(GridCharacter, :count).by(5)
    end

    it 'creates GridCharacters with the correct attributes' do
      character_processor.process
      grid_chars = GridCharacter.where(party_id: party.id).order(:position)

      expect(grid_chars[0].character.granblue_id).to eq(deck_data.dig('deck', 'npc', '1', 'master', 'id'))
      expect(grid_chars[3].uncap_level).to eq(deck_data.dig('deck', 'npc', '4', 'param', 'evolution').to_i)
      expect(grid_chars[4].position).to eq(4)
    end

    it 'assigns all positions sequentially from 0' do
      character_processor.process
      positions = GridCharacter.where(party_id: party.id).pluck(:position).sort
      expect(positions).to eq((0..4).to_a)
    end
  end

  describe 'awakening and perpetuity survive collection sync' do
    let(:deck_data) do
      data = JSON.parse(Rails.root.join("spec/fixtures/deck_sample2.json").read)
      # Add npc_arousal_form to first character (Attack awakening)
      data['deck']['npc']['1']['param']['npc_arousal_form'] = 2
      # Ensure perpetuity is set
      data['deck']['npc']['1']['param']['has_npcaugment_constant'] = true
      data
    end

    it 'preserves awakening on grid character after collection sync' do
      character_processor.process
      gc = GridCharacter.where(party_id: party.id).order(:position).first
      awakening = Awakening.find_by(slug: 'character-atk', object_type: 'Character')

      expect(gc.awakening).to eq(awakening)
    end

    it 'preserves perpetuity on grid character after collection sync' do
      character_processor.process
      gc = GridCharacter.where(party_id: party.id).order(:position).first

      expect(gc.perpetuity).to be(true)
    end

    it 'syncs awakening to the collection character' do
      character_processor.process
      gc = GridCharacter.where(party_id: party.id).order(:position).first
      cc = gc.collection_character
      awakening = Awakening.find_by(slug: 'character-atk', object_type: 'Character')

      expect(cc).to be_present
      expect(cc.awakening).to eq(awakening)
    end
  end

  context 'with invalid character data' do
    let(:deck_data) { 'invalid data' }

    it 'does not create any GridCharacter records' do
      expect { character_processor.process }.not_to change(GridCharacter, :count)
    end
  end
end
