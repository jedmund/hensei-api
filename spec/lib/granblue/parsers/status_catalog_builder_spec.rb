# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::StatusCatalogBuilder do
  def character(name, statuses)
    text = statuses.map { |s| "{{status|#{s}}}" }.join(' ')
    Character.without_skill_build do
      create(:character, name_en: name, wiki_raw: "{{Character\n|abilitycount=1\n|a1_name=A\n|a1_effdesc=#{text}\n}}")
    end
  end

  describe '.build_for' do
    it 'adds the statuses the given characters name, and nothing else' do
      given = character('Given', %w[Burned])
      character('Other', ['Frozen'])
      result = described_class.build_for([given])
      expect(result).to include(created: 1)
      expect(Status.pluck(:name_en)).to eq(['Burned'])
    end

    it 'fills blank attributes but never overwrites what build_all wrote' do
      status = Status.create!(name_en: 'Burned', category: 'buff', wiki_slug: nil)
      described_class.build_for([character('Given', %w[Burned])])
      expect(status.reload.category).to eq('buff')
      expect(status.wiki_slug).to eq('Burned')
    end
  end

  describe '.build_all' do
    it 'merges every character and keeps the strongest category' do
      Status.create!(name_en: 'Burned', category: 'buff')
      character('One', %w[Burned])
      described_class.build_all
      expect(Status.find_by(name_en: 'Burned').category).to eq('buff')
      expect(Status.count).to eq(1)
    end
  end
end
