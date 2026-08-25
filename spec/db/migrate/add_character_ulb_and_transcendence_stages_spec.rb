# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20260824000000_add_character_ulb_and_transcendence_stages').to_s

RSpec.describe AddCharacterUlbAndTranscendenceStages do
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
