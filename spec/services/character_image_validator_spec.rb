# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterImageValidator do
  let(:valid_id) { '3040001000' }

  describe '#valid?' do
    context 'with invalid format' do
      it 'rejects nil' do
        validator = described_class.new(nil)
        expect(validator.valid?).to be false
        expect(validator.error_message).to include('Invalid granblue_id format')
      end

      it 'rejects short IDs' do
        validator = described_class.new('12345')
        expect(validator.valid?).to be false
      end

      it 'rejects non-numeric IDs' do
        validator = described_class.new('abcdefghij')
        expect(validator.valid?).to be false
      end
    end

    context 'with valid format' do
      let(:http_double) { instance_double(Net::HTTP) }
      let(:validator) { described_class.new(valid_id) }

      before do
        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:use_ssl=)
        allow(http_double).to receive(:open_timeout=)
        allow(http_double).to receive(:read_timeout=)
        allow(http_double).to receive(:verify_mode=)
      end

      it 'returns true when image is accessible' do
        allow(http_double).to receive(:request).and_return(double(code: '200'))

        expect(validator.valid?).to be true
        expect(validator.image_urls[:main]).to include('npc/f/3040001000_01.jpg')
      end

      it 'returns false when image is not found' do
        allow(http_double).to receive(:request).and_return(double(code: '404'))

        expect(validator.valid?).to be false
        expect(validator.error_message).to include('HTTP 404')
      end

      it 'handles timeouts gracefully' do
        allow(http_double).to receive(:request).and_raise(Net::OpenTimeout, 'timed out')

        expect(validator.valid?).to be false
        expect(validator.error_message).to include('timed out')
      end

      it 'handles general errors gracefully' do
        allow(http_double).to receive(:request).and_raise(StandardError, 'connection reset')

        expect(validator.valid?).to be false
        expect(validator.error_message).to include('connection reset')
      end

      it 'builds URLs with _01 suffix for all sizes' do
        allow(http_double).to receive(:request).and_return(double(code: '200'))
        validator.valid?

        aggregate_failures do
          expect(validator.image_urls[:main]).to include('f/3040001000_01.jpg')
          expect(validator.image_urls[:grid]).to include('m/3040001000_01.jpg')
          expect(validator.image_urls[:square]).to include('s/3040001000_01.jpg')
        end
      end
    end
  end

  describe '#exists_in_db?' do
    it 'checks Character table for granblue_id' do
      allow(Character).to receive(:exists?).with(granblue_id: valid_id).and_return(true)
      validator = described_class.new(valid_id)
      expect(validator.exists_in_db?).to be true
    end
  end
end
