# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Processors::BaseProcessor, type: :model do
  # NOTE: BaseProcessor.new expects (party, data, options = {})
  let(:dummy_party) { nil }
  let(:dummy_data) { {} }
  let(:processor) { Processors::DummyBaseProcessor.new(dummy_party, dummy_data) }

  before do
    stub_const('Processors::DummyBaseProcessor', Class.new(described_class) do
      # A dummy implementation of process.
      def process
        'processed'
      end

      # Expose the protected log method as public for testing.
      def public_log(message)
        log(message)
      end
    end)
    allow(Rails.logger).to receive(:info)
  end

  describe '#process' do
    it 'returns the dummy processed value' do
      expect(processor.process).to eq('processed')
    end
  end

  describe '#public_log' do
    it 'logs a message containing the processor class name' do
      message = 'Test log message'
      processor.public_log(message)
      expect(Rails.logger).to have_received(:info).with(a_string_including('DummyBaseProcessor', message))
    end

    it 'formats log with bracket-wrapped class name' do
      processor.public_log('any message')
      expect(Rails.logger).to have_received(:info).with(/\[.*DummyBaseProcessor.*\]/)
    end
  end

  describe '#initialize' do
    it 'stores party and data' do
      party = create(:party)
      data = { 'key' => 'value' }
      proc = Processors::DummyBaseProcessor.new(party, data)
      expect(proc.process).to eq('processed')
    end
  end
end
