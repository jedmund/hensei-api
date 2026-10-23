# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::StatusNameRule do
  def propose(name, vocabulary: [])
    described_class.propose(name, vocabulary: vocabulary.to_set { |n| Status.normalize_name(n) })
  end

  it 'turns Boosted/Lowered into Up/Down and keeps the modifiers' do
    expect(propose("Hostility Boosted (Stackable/Can't be removed)").to).to eq("Hostility Up (Stackable/Can't be removed)")
    expect(propose('DEF Lowered').to).to eq('DEF Down')
    expect(propose('Accuracy Lowered 3').to).to eq('Accuracy Down 3')
  end

  it 'turns a participle into its base form when the wiki uses that name' do
    vocabulary = %w[Blind Charm Hype Substitute Burn]
    expect(%w[Blinded Charmed Hyped Substituted Burned].map { |n| propose(n, vocabulary: vocabulary).to })
      .to eq(%w[Blind Charm Hype Substitute Burn])
    expect(propose("Charmed (Can't be removed)", vocabulary: vocabulary).to).to eq("Charm (Can't be removed)")
  end

  it 'keeps a participle with no base form, and flags it' do
    proposal = propose('Paralyzed')
    expect(proposal.to).to eq('Paralyzed')
    expect(proposal.flags.first).to include('kept')
    expect(propose('Greed').flags).to be_empty
  end

  it 'flags wording that may read wrongly' do
    expect(propose('ATK Sharply Boosted').flags.first).to include('adverb')
    expect(propose('Dark Lowered (Stackable)').flags.first).to include('element')
  end

  it 'records which rules renamed a name, in the order of CharacterSkills::StatusNameRules' do
    expect(propose('Fire ATK Lowered').rules).to eq(['lowered_to_down'])
    expect(propose('Blinded', vocabulary: ['Blind']).rules).to eq(['participle_to_base'])
    expect(propose('Veil').rules).to eq([])
  end

  it 'gives every rule an id, a plain pattern, an example and a note' do
    rules = CharacterSkills::StatusNameRules::RULES
    expect(rules.map(&:id)).to eq(rules.map(&:id).uniq)
    expect(rules).to all(have_attributes(pattern: be_present, example: be_present, note: be_present))
  end
end
