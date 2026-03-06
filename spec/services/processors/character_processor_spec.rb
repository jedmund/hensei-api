# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Processors::CharacterProcessor, type: :model do
  let(:party) { create(:party) }
  let(:deck_data) do
    file_path = Rails.root.join('spec', 'fixtures', 'deck_sample2.json')
    JSON.parse(File.read(file_path))
  end

  subject! { described_class.new(party, deck_data, language: 'en') }

  context 'with valid character data' do
    it 'creates the correct number of GridCharacter records' do
      expect { subject.process }.to change(GridCharacter, :count).by(5)
    end

    it 'creates GridCharacters with the correct attributes' do
      subject.process
      grid_chars = GridCharacter.where(party_id: party.id).order(:position)

      expect(grid_chars[0].character.granblue_id).to eq(deck_data.dig('deck', 'npc', '1', 'master', 'id'))
      expect(grid_chars[3].uncap_level).to eq(deck_data.dig('deck', 'npc', '4', 'param', 'evolution').to_i)
      expect(grid_chars[4].position).to eq(4)
    end

    it 'assigns all positions sequentially from 0' do
      subject.process
      positions = GridCharacter.where(party_id: party.id).pluck(:position).sort
      expect(positions).to eq((0..4).to_a)
    end
  end

  context 'with invalid character data' do
    let(:deck_data) { 'invalid data' }

    it 'does not create any GridCharacter records' do
      expect { subject.process }.not_to change(GridCharacter, :count)
    end
  end
end
