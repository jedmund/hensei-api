# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponImageValidator do
  let(:valid_id) { '1040001000' }

  describe '#valid?' do
    context 'with invalid format' do
      it 'rejects non-10-digit IDs' do
        validator = described_class.new('999')
        expect(validator.valid?).to be false
        expect(validator.error_message).to include('Invalid granblue_id format')
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
      end

      it 'returns false when image is not found' do
        allow(http_double).to receive(:request).and_return(double(code: '404'))
        expect(validator.valid?).to be false
      end

      it 'builds URLs without variant suffix' do
        allow(http_double).to receive(:request).and_return(double(code: '200'))
        validator.valid?

        aggregate_failures do
          expect(validator.image_urls[:main]).to include('weapon/ls/1040001000.jpg')
          expect(validator.image_urls[:grid]).to include('weapon/m/1040001000.jpg')
          expect(validator.image_urls[:square]).to include('weapon/s/1040001000.jpg')
        end
      end
    end
  end

  describe '#exists_in_db?' do
    it 'checks Weapon table for granblue_id' do
      allow(Weapon).to receive(:exists?).with(granblue_id: valid_id).and_return(true)
      validator = described_class.new(valid_id)
      expect(validator.exists_in_db?).to be true
    end
  end
end
