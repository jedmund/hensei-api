# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DifficultyConfig do
  describe '.instance' do
    it 'creates the singleton row at version 1 when there is none' do
      expect { described_class.instance }.to change(described_class, :count).from(0).to(1)
      expect(described_class.current_version).to eq(1)
    end

    it 'returns the existing row' do
      row = described_class.create!(ruleset_version: 4)
      expect(described_class.instance).to eq(row)
    end
  end

  describe '.bump_version!' do
    it 'increments the stored ruleset version and returns it' do
      described_class.create!(ruleset_version: 3)

      expect(described_class.bump_version!).to eq(4)
      expect(described_class.current_version).to eq(4)
    end

    it 'keeps a single row' do
      described_class.instance
      2.times { described_class.bump_version! }

      expect(described_class.count).to eq(1)
      expect(described_class.current_version).to eq(3)
    end
  end
end
