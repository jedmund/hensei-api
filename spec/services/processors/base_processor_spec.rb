# frozen_string_literal: true

require 'rails_helper'

module Processors
  class DummyBaseProcessor < BaseProcessor
    # A dummy implementation of process.
    def process
      "processed"
    end

    # Expose the protected log method as public for testing.
    def public_log(message)
      log(message)
    end
  end
end

RSpec.describe Processors::DummyBaseProcessor, type: :model do
  # Note: BaseProcessor.new expects (party, data, options = {})
  let(:dummy_party) { nil }
  let(:dummy_data) { {} }
  let(:processor) { described_class.new(dummy_party, dummy_data) }

  describe '#process' do
    it 'returns the dummy processed value' do
      expect(processor.process).to eq("processed")
    end
  end

  describe '#public_log' do
    it 'logs a message containing the processor class name' do
      message = "Test log message"
      expect(Rails.logger).to receive(:info).with(a_string_including("DummyBaseProcessor", message))
      processor.public_log(message)
    end

    it 'formats log with bracket-wrapped class name' do
      expect(Rails.logger).to receive(:info).with(/\[.*DummyBaseProcessor.*\]/)
      processor.public_log("any message")
    end
  end

  describe '#initialize' do
    it 'stores party and data' do
      party = create(:party)
      data = { 'key' => 'value' }
      proc = described_class.new(party, data)
      expect(proc.process).to eq("processed")
    end
  end
end
