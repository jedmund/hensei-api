# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20260824000000_add_character_ulb_and_transcendence_stages').to_s

RSpec.describe AddCharacterUlbAndTranscendenceStages do
  describe '#reclassify_story_ulb_characters' do
    subject(:reclassify) { described_class.new.send(:reclassify_story_ulb_characters) }

    it 'moves the misrouted FLB date for a current story ULB row' do
      ulb_date = Date.new(2019, 8, 22)
      character = create(:character, :special_ulb)
      character.update_columns(
        flb_date: ulb_date,
        ulb: false,
        ulb_date: nil,
        transcendence: true,
        transcendence_date: nil
      )

      reclassify

      character.reload
      aggregate_failures do
        expect(character.flb_date).to be_nil
        expect(character.ulb_date).to eq(ulb_date)
        expect(character.ulb).to be true
        expect(character.transcendence).to be false
      end
    end

    it 'preserves the FLB date when a legacy story ULB row has a final uncap date' do
      flb_date = Date.new(2019, 8, 22)
      ulb_date = Date.new(2026, 8, 1)
      character = create(:character, :special_ulb)
      character.update_columns(
        flb_date: flb_date,
        ulb: false,
        ulb_date: nil,
        transcendence: true,
        transcendence_date: ulb_date
      )

      reclassify

      character.reload
      aggregate_failures do
        expect(character.flb_date).to eq(flb_date)
        expect(character.ulb_date).to eq(ulb_date)
        expect(character.ulb).to be true
        expect(character.transcendence).to be false
      end
    end
  end

  describe '#clamp_legacy_collection_transcendence_stages' do
    it 'clamps collection stages from the old 0..10 domain to stage 5' do
      character = create(:character, :transcendable)
      collection_character = create(:collection_character, character: character,
                                                            uncap_level: 5,
                                                            transcendence_step: 5)
      collection_character.update_column(:transcendence_step, 10)

      described_class.new.send(:clamp_legacy_collection_transcendence_stages)

      expect(collection_character.reload.transcendence_step).to eq(5)
    end
  end
end
