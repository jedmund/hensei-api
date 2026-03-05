# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::BaseParser do
  # Concrete subclass for testing
  let(:test_parser_class) do
    Class.new(described_class) do
      def parse(hash)
        hash
      end

      def persist(info)
        # no-op
      end
    end
  end

  let(:entity) do
    double('Entity', wiki_en: 'Katalina', wiki_raw: nil,
           :wiki_en= => nil, :wiki_raw= => nil, save!: true)
  end

  let(:parser) { test_parser_class.new(entity) }

  describe '#parse_string' do
    it 'extracts key-value pairs from wiki markup' do
      text = "|name = Katalina\n|element = Water"
      result = parser.send(:parse_string, text)
      expect(result['name']).to eq('Katalina')
      expect(result['element']).to eq('Water')
    end

    it 'stops at Gameplay Notes' do
      text = "|name = Katalina\n== Gameplay Notes ==\n|hidden = secret"
      result = parser.send(:parse_string, text)
      expect(result).to have_key('name')
      expect(result).not_to have_key('hidden')
    end

    it 'extracts template names from {{ lines' do
      text = "{{CharacterSSR\n|name = Katalina"
      result = parser.send(:parse_string, text)
      expect(result[:template]).to eq('CharacterSSR')
    end

    it 'skips template values that match placeholder pattern' do
      text = "|name = {{{name|}}}"
      result = parser.send(:parse_string, text)
      expect(result).not_to have_key('name')
    end
  end

  describe '#extract_redirected_string' do
    it 'extracts redirect target' do
      text = '#REDIRECT [[Katalina (Water)]]'
      result = parser.send(:extract_redirected_string, text)
      expect(result).to eq('Katalina (Water)')
    end

    it 'returns nil for non-redirect' do
      result = parser.send(:extract_redirected_string, '|name = Katalina')
      expect(result).to be_nil
    end
  end

  describe '#parse' do
    it 'raises NotImplementedError on base class' do
      base_parser = described_class.new(entity)
      expect { base_parser.send(:parse, {}) }.to raise_error(NotImplementedError)
    end
  end

  describe '#persist' do
    it 'raises NotImplementedError on base class' do
      base_parser = described_class.new(entity)
      expect { base_parser.send(:persist, {}) }.to raise_error(NotImplementedError)
    end
  end

  describe '#parse_date' do
    it 'parses valid date string' do
      expect(parser.send(:parse_date, '2024-03-15')).to eq(Date.new(2024, 3, 15))
    end

    it 'returns nil for blank string' do
      expect(parser.send(:parse_date, '')).to be_nil
      expect(parser.send(:parse_date, nil)).to be_nil
    end
  end
end
