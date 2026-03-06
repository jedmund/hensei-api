# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Importers::BaseImporter do
  # Concrete subclass for testing
  let(:test_importer_class) do
    Class.new(described_class) do
      private

      def model_class
        Weapon
      end

      def build_attributes(row)
        {
          name_en: parse_value(row['name_en']),
          granblue_id: parse_value(row['granblue_id']),
          rarity: parse_integer(row['rarity']),
          element: parse_integer(row['element'])
        }
      end
    end
  end

  let(:importer) { test_importer_class.new('/tmp/test.csv') }

  describe 'parsing helpers' do
    describe '#parse_value' do
      it 'returns nil for nil' do
        expect(importer.send(:parse_value, nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(importer.send(:parse_value, '')).to be_nil
      end

      it 'returns nil for whitespace-only string' do
        expect(importer.send(:parse_value, '   ')).to be_nil
      end

      it 'returns the value for non-empty string' do
        expect(importer.send(:parse_value, 'hello')).to eq('hello')
      end
    end

    describe '#parse_integer' do
      it 'returns nil for nil' do
        expect(importer.send(:parse_integer, nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(importer.send(:parse_integer, '')).to be_nil
      end

      it 'converts string to integer' do
        expect(importer.send(:parse_integer, '42')).to eq(42)
      end
    end

    describe '#parse_float' do
      it 'returns nil for nil' do
        expect(importer.send(:parse_float, nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(importer.send(:parse_float, '')).to be_nil
      end

      it 'converts string to float' do
        expect(importer.send(:parse_float, '3.14')).to eq(3.14)
      end
    end

    describe '#parse_boolean' do
      it 'returns nil for nil' do
        expect(importer.send(:parse_boolean, nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(importer.send(:parse_boolean, '')).to be_nil
      end

      it 'returns true for "true"' do
        expect(importer.send(:parse_boolean, 'true')).to be true
      end

      it 'returns false for "false"' do
        expect(importer.send(:parse_boolean, 'false')).to be false
      end
    end

    describe '#parse_date' do
      it 'returns nil for nil' do
        expect(importer.send(:parse_date, nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(importer.send(:parse_date, '')).to be_nil
      end

      it 'parses valid date' do
        expect(importer.send(:parse_date, '2024-03-15')).to eq(Date.new(2024, 3, 15))
      end

      it 'returns nil for invalid date' do
        expect(importer.send(:parse_date, 'not-a-date')).to be_nil
      end
    end

    describe '#parse_array' do
      it 'returns empty array for nil' do
        expect(importer.send(:parse_array, nil)).to eq([])
      end

      it 'returns empty array for empty string' do
        expect(importer.send(:parse_array, '')).to eq([])
      end

      it 'parses PostgreSQL array format' do
        expect(importer.send(:parse_array, '{fire,water,earth}')).to eq(%w[fire water earth])
      end
    end

    describe '#parse_integer_array' do
      it 'parses and converts to integers' do
        expect(importer.send(:parse_integer_array, '{1,2,3}')).to eq([1, 2, 3])
      end

      it 'returns empty array for nil' do
        expect(importer.send(:parse_integer_array, nil)).to eq([])
      end
    end
  end

  describe '#model_class' do
    it 'raises NotImplementedError on base class' do
      base = described_class.new('/tmp/test.csv')
      expect { base.send(:model_class) }.to raise_error(NotImplementedError)
    end
  end

  describe '#build_attributes' do
    it 'raises NotImplementedError on base class' do
      base = described_class.new('/tmp/test.csv')
      expect { base.send(:build_attributes, {}) }.to raise_error(NotImplementedError)
    end
  end

  describe '#format_standard_error' do
    it 'returns message for non-verbose mode' do
      error = StandardError.new('something broke')
      result = importer.send(:format_standard_error, error)
      expect(result).to eq('something broke')
    end

    it 'includes backtrace in verbose mode' do
      verbose_importer = test_importer_class.new('/tmp/test.csv', verbose: true)
      error = StandardError.new('something broke')
      allow(error).to receive(:backtrace).and_return(['/path/to/file.rb:1', '/path/to/file.rb:2'])
      result = verbose_importer.send(:format_standard_error, error)
      expect(result).to include('Backtrace:')
    end
  end

  describe '#initialize' do
    it 'initializes with empty record tracking hashes' do
      aggregate_failures do
        expect(importer.new_records).to be_empty
        expect(importer.updated_records).to be_empty
      end
    end
  end
end
