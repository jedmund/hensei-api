# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::Wiki do
  describe 'constant mappings' do
    it 'maps proficiencies to integers' do
      expect(described_class.proficiencies).to include('Sabre' => 1, 'Katana' => 10)
      expect(described_class.proficiencies.keys.length).to eq(10)
    end

    it 'maps elements to integers' do
      expect(described_class.elements).to include(
        'Wind' => 1, 'Fire' => 2, 'Water' => 3,
        'Earth' => 4, 'Dark' => 5, 'Light' => 6
      )
    end

    it 'maps rarities to integers' do
      expect(described_class.rarities).to eq('R' => 1, 'SR' => 2, 'SSR' => 3)
    end

    it 'maps races to integers' do
      expect(described_class.races).to include('Human' => 1, 'Primal' => 5)
    end

    it 'maps genders to integers' do
      expect(described_class.genders).to include('m' => 1, 'f' => 2)
    end

    it 'maps boolean values' do
      expect(described_class.boolean).to eq('yes' => true, 'no' => false)
    end

    it 'maps character_series to integers' do
      expect(described_class.character_series).to include('grand' => 1, 'zodiac' => 2)
      expect(described_class.character_series.keys.length).to eq(15)
    end
  end

  describe '.promotions_from_obtain' do
    let(:ordinary) { [1, 4, 5, 6, 7, 8, 9, 10, 11] }

    it 'puts ordinary Premium items in every Premium-type banner' do
      expect(described_class.promotions_from_obtain('premium,normal')).to eq(ordinary)
      expect(described_class.promotions_from_obtain('premium,normal;classic3')).to eq(ordinary + [12])
      expect(described_class.promotions_from_obtain('premium,classic2,normal,non-ticketable')).to eq((ordinary + [3]).sort)
    end

    it 'puts limited items only in their limited pool' do
      expect(described_class.promotions_from_obtain('premium,gala,flash')).to eq([4])
      expect(described_class.promotions_from_obtain('premium,gala,normal')).to eq([5])
      expect(described_class.promotions_from_obtain('premium,zodiac,2020')).to eq([5])
      expect(described_class.promotions_from_obtain('premium,summer')).to eq([7])
      expect(described_class.promotions_from_obtain('premium,swimsuit')).to eq([7])
      expect(described_class.promotions_from_obtain('premium,holiday')).to eq([9])
      expect(described_class.promotions_from_obtain('premium,collab')).to eq([10])
    end

    it 'adds Classic pools only when named' do
      expect(described_class.promotions_from_obtain('classic')).to eq([2])
      expect(described_class.promotions_from_obtain('classic2')).to eq([3])
      expect(described_class.promotions_from_obtain('classic3')).to eq([12])
    end

    it 'leaves non-gacha items out of every pool' do
      expect(described_class.promotions_from_obtain('event,collab,BLEACH: Echoes in the Blue Hollow')).to eq([])
      expect(described_class.promotions_from_obtain('shop,trade moons,gold,30;premium,ticket')).to eq([])
      expect(described_class.promotions_from_obtain('premium,special,[[Premium Draw|Christmas Holiday Draw Set]]')).to eq([])
      expect(described_class.promotions_from_obtain('event')).to eq([])
      expect(described_class.promotions_from_obtain(nil)).to eq([])
    end
  end

  describe '#initialize' do
    it 'defaults to wikitext prop' do
      wiki = described_class.new
      expect(wiki.instance_variable_get(:@props)).to eq('wikitext')
    end

    it 'accepts custom props' do
      wiki = described_class.new(props: %w[wikitext categories])
      expect(wiki.instance_variable_get(:@props)).to eq('wikitext|categories')
    end
  end

  describe '#fetch' do
    let(:wiki) { described_class.new }

    before do
      allow(Rails.application.credentials).to receive(:wiki_user_agent).and_return('TestBot/1.0')
    end

    context 'when response is 200 with valid data' do
      it 'returns wikitext content' do
        response = double('Response',
          code: 200,
          key?: false,
          :[] => nil)
        allow(response).to receive(:key?).with('error').and_return(false)
        allow(response).to receive(:[]).with('parse').and_return({
          'wikitext' => { '*' => '|name = Katalina' }
        })

        allow(HTTParty).to receive(:get).and_return(response)
        expect(wiki.fetch('Katalina')).to eq('|name = Katalina')
      end
    end

    context 'when response has error key' do
      it 'raises WikiError with error details' do
        response = double('Response', code: 200)
        allow(response).to receive(:key?).with('error').and_return(true)
        allow(response).to receive(:[]).with('error').and_return({
          'code' => 'missingtitle',
          'info' => 'Page not found'
        })

        allow(HTTParty).to receive(:get).and_return(response)
        expect { wiki.fetch('Missing') }.to raise_error(Granblue::WikiError, /missingtitle|Page not found/)
      end
    end

    context 'when response is 404' do
      it 'raises WikiError' do
        response = double('Response', code: 404)
        allow(HTTParty).to receive(:get).and_return(response)
        expect { wiki.fetch('Missing') }.to raise_error(Granblue::WikiError)
      end
    end

    context 'when response is 500' do
      it 'raises WikiError' do
        response = double('Response', code: 500)
        allow(HTTParty).to receive(:get).and_return(response)
        expect { wiki.fetch('Broken') }.to raise_error(Granblue::WikiError)
      end
    end

    context 'when network error occurs' do
      it 'raises the underlying error' do
        allow(HTTParty).to receive(:get).and_raise(Net::ReadTimeout)
        expect { wiki.fetch('Timeout') }.to raise_error(Net::ReadTimeout)
      end
    end
  end
end
