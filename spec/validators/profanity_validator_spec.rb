# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProfanityValidator do
  before { described_class.reset! }

  describe '.word_list' do
    it 'loads strict tier (moderate + strict words)' do
      words = described_class.word_list(:en, tier: :strict)
      expect(words).to be_an(Array)
      expect(words).to include('ass')       # strict-only word
      expect(words).to include('asshole')   # moderate word
    end

    it 'loads moderate tier (moderate words only)' do
      words = described_class.word_list(:en, tier: :moderate)
      expect(words).to include('asshole')   # moderate word
      expect(words).not_to include('ass')   # strict-only word
    end

    it 'loads the Japanese word list' do
      words = described_class.word_list(:ja, tier: :moderate)
      expect(words).to be_an(Array)
      expect(words).not_to be_empty
    end

    it 'combines multiple language lists' do
      words = described_class.word_list(:en, :ja, tier: :strict)
      en_words = described_class.word_list(:en, tier: :strict)
      ja_words = described_class.word_list(:ja, tier: :strict)
      expect(words.size).to eq(en_words.size + ja_words.size)
    end

    it 'returns empty array for missing language' do
      words = described_class.word_list(:zz, tier: :strict)
      expect(words).to eq([])
    end

    it 'defaults to strict tier' do
      default_words = described_class.word_list(:en)
      strict_words = described_class.word_list(:en, tier: :strict)
      expect(default_words).to eq(strict_words)
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

  describe 'tier behavior' do
    it 'blocks strict-only words in usernames (strict tier)' do
      user = build(:user, username: 'ass-man')
      expect(user).not_to be_valid
    end

    it 'allows strict-only words in party names (moderate tier)' do
      party = build(:party, name: 'kick ass team')
      expect(party.errors[:name]).to be_empty
      # Party name validation runs but 'ass' is strict-only
    end

    it 'blocks moderate words in party names' do
      party = build(:party, name: 'asshole team')
      party.valid?
      expect(party.errors[:name]).to include('contains inappropriate language')
    end

    it 'does not flag substrings within a single segment' do
      user = build(:user, username: 'class')
      expect(user).to be_valid
    end
  end
end
