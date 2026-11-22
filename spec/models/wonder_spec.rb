# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Wonder do
  describe '#required_character_ids' do
    let(:eternal) { create(:character_series, slug: 'eternal') }

    def character(game_ids)
      create(:character, character_id: game_ids)
    end

    it 'is empty for a Wonder that boosts everyone' do
      expect(create(:wonder).required_character_ids).to eq([])
    end

    it "lists every version of the series' single characters, not duo units" do
      original = character([3040])
      seasonal = character([3041])
      duo = character([3040, 3277])
      outsider = character([3999])
      [original, seasonal, duo].each { |c| create(:character_series_membership, character: c, character_series: eternal) }
      wonder = create(:wonder, required_character_series: 'eternal')

      expect(wonder.required_character_ids).to contain_exactly(original.granblue_id, seasonal.granblue_id)
      expect(wonder.required_character_ids).not_to include(duo.granblue_id, outsider.granblue_id)
    end

    it 'lists every version of the required game characters, not duo units' do
      katalina = character([2005])
      grand_katalina = character([2005])
      duo = character([2005, 2124])
      someone_else = character([2999])
      wonder = create(:wonder, required_character_game_ids: [2005, 2006])

      expect(wonder.required_character_ids).to contain_exactly(katalina.granblue_id, grand_katalina.granblue_id)
      expect(wonder.required_character_ids).not_to include(duo.granblue_id, someone_else.granblue_id)
    end
  end
end
