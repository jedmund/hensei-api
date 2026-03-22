# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProfanityValidator do
  before { described_class.reset! }

  describe '.word_list' do
    it 'loads the English word list' do
      words = described_class.word_list(:en)
      expect(words).to be_an(Array)
      expect(words).not_to be_empty
      expect(words).to include('ass')
    end

    it 'loads the Japanese word list' do
      words = described_class.word_list(:ja)
      expect(words).to be_an(Array)
      expect(words).not_to be_empty
    end

    it 'combines multiple language lists' do
      words = described_class.word_list(:en, :ja)
      en_words = described_class.word_list(:en)
      ja_words = described_class.word_list(:ja)
      expect(words.size).to eq(en_words.size + ja_words.size)
    end

    it 'caches loaded lists' do
      described_class.word_list(:en)
      expect(YAML).not_to receive(:load_file)
      described_class.word_list(:en)
    end

    it 'returns empty array for missing language file' do
      words = described_class.word_list(:zz)
      expect(words).to eq([])
    end
  end

  describe '.reserved_list' do
    it 'loads the reserved word list' do
      words = described_class.reserved_list
      expect(words).to include('admin')
      expect(words).to include('system')
      expect(words).to include('hensei')
    end
  end

  describe 'segment matching' do
    it 'catches offensive segments split by hyphens' do
      user = build(:user, username: 'ass-man')
      expect(user).not_to be_valid
    end

    it 'catches offensive segments split by underscores' do
      user = build(:user, username: 'big_ass')
      expect(user).not_to be_valid
    end

    it 'does not flag substrings within a single segment' do
      user = build(:user, username: 'class')
      expect(user).to be_valid
    end
  end
end
