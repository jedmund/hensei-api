# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::StatusRenameList do
  def list(statuses, mentions: {}, groups: [])
    described_class.new(statuses: statuses.map { |name, category| { name: name, category: category, effects: 1 } },
                        mentions: mentions, groups: groups)
  end

  it 'merges names the rule makes equal, and extra groups, under the most-mentioned spelling' do
    result = list([['DEF Down', 'debuff'], ['DEF Lowered', 'debuff'], ['Counter on DMG', 'buff'], ['Counters on DMG', 'buff']],
                  mentions: { 'def down' => 5, 'def lowered' => 9, 'counters on dmg' => 3, 'counter on dmg' => 1 },
                  groups: [['Counter on DMG', 'Counters on DMG']])
    expect(result.groups.map { |g| [g.canonical, g.statuses.map { |m| m[:name] }.sort] })
      .to contain_exactly(['DEF Down', ['DEF Down', 'DEF Lowered']], ['Counters on DMG', ['Counter on DMG', 'Counters on DMG']])
    expect(result.aliases).to contain_exactly(
      { 'wiki_name' => 'DEF Lowered', 'name_en' => 'DEF Down', 'reason' => 'D32 naming rule' },
      { 'wiki_name' => 'Counter on DMG', 'name_en' => 'Counters on DMG', 'reason' => 'D32 naming rule' }
    )
  end

  it 'flags Down on a buff and lists it first' do
    result = list([%w[Veil buff], ['Dark DMG Lowered', 'buff'], ['ATK Boosted', 'buff']])
    expect(result.groups.first.canonical).to eq('Dark DMG Down')
    expect(result.groups.first.flags).to include('Down on a buff')
    expect(result.groups.map(&:canonical)).not_to include('Veil')
  end
end
