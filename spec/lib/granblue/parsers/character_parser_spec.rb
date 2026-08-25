# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterParser do
  describe '#fetch' do
    let(:granblue_id) { '3030001000' }
    let(:wiki_raw) do
      <<~WIKI
        |name = Katalina
        |jpname = カタリナ
        |id = #{granblue_id}
        |charid = 0001
        |rarity = SR
        |element = Water
        |gender = f
        |weapon = Sabre
        |race = Human
        |5star = yes
        |5star_date = 2019-08-22
        |uncap_type = story
        |max_evo = 5
        |release_date = 2015-03-10
      WIKI
    end
    let(:character) do
      create(
        :character,
        :special_ulb,
        granblue_id: granblue_id,
        wiki_en: 'Katalina',
        wiki_raw: wiki_raw,
        flb_date: Date.new(2019, 8, 22),
        ulb_date: nil,
        transcendence_date: Date.new(2019, 8, 22)
      )
    end
    let(:parser) { described_class.new(granblue_id: character.granblue_id, use_local: true) }

    it 'classifies and saves a current story character as ULB' do
      wiki_data = parser.send(:parse_string, wiki_raw)
      parsed = parser.send(:parse, wiki_data)

      aggregate_failures do
        expect(parsed[:flb]).to be true
        expect(parsed[:special]).to be true
        expect(parsed[:ulb]).to be true
        expect(parsed[:transcendence]).to be false
        expect(parsed[:dates][:flb_date]).to be_nil
        expect(parsed[:dates][:ulb_date]).to eq(Date.new(2019, 8, 22))
        expect(parsed[:dates][:transcendence_date]).to be_nil
      end

      expect(parser.fetch(save: true)).to be true

      character.reload
      aggregate_failures do
        expect(character.flb_date).to be_nil
        expect(character.ulb_date).to eq(Date.new(2019, 8, 22))
        expect(character.transcendence_date).to be_nil
      end
    end
  end
end
