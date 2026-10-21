# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::WikiThrottle do
  describe '.clamp' do
    it 'defaults to the minimum' do
      expect(described_class.clamp(nil)).to eq(2.0)
    end

    it 'keeps a longer delay' do
      expect(described_class.clamp('3.5')).to eq(3.5)
    end

    it 'raises a shorter delay to the minimum and says so' do
      notes = []
      expect(described_class.clamp('0.5', warn: notes.method(:<<))).to eq(2.0)
      expect(notes.first).to include('below the 2.0s minimum')
    end
  end

  describe '.wait' do
    it 'sleeps for the given time' do
      allow(described_class).to receive(:sleep)
      described_class.wait(2.0)
      expect(described_class).to have_received(:sleep).with(2.0)
    end

    it 'does nothing for zero' do
      allow(described_class).to receive(:sleep)
      described_class.wait(0)
      expect(described_class).not_to have_received(:sleep)
    end
  end
end
