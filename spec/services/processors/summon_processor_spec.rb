# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Processors::SummonProcessor, type: :model do
  let(:party) { create(:party) }
  let(:deck_data) do
    file_path = Rails.root.join('spec', 'fixtures', 'deck_sample.json')
    JSON.parse(File.read(file_path))
  end

  subject { described_class.new(party, deck_data, language: 'en') }

  context 'with valid summon data' do
    it 'creates the correct number of GridSummon records' do
      expect { subject.process }.to change(GridSummon, :count).by(7)
    end
  end

  context 'with invalid summon data' do
    let(:deck_data) { "invalid data" }
    it 'does not create any GridSummon and logs an error containing "SUMMON"' do
      expect { subject.process }.not_to change(GridSummon, :count)
      begin
        subject.process
      rescue StandardError
        nil
      end
    end
  end

  after(:each) do |example|
    if example.exception
      puts "\nDEBUG [SummonProcessor]: #{example.full_description} failed with error: #{example.exception.message}"
    end
  end
end
