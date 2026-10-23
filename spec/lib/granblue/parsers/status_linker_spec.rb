# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::StatusLinker do
  def skill(text, details)
    { mentions: Granblue::Parsers::StatusMentions.in(text),
      details: details.flat_map { |category, ids| ids.map { |id| { category: category, id: id } } } }
  end

  it 'links one gained name to the one buff id, and one inflicted name to the one debuff id' do
    links = described_class.new([skill('Gain {{status|DEF Up}}. Inflict {{status|DEF Down}} on a foe.',
                                       'buff' => ['1019'], 'debuff' => ['1020'])]).links
    expect(links).to eq('def up' => '1019', 'def down' => '1020')
  end

  it 'links in rounds: a known name leaves the other one to one' do
    links = described_class.new([skill('Gain {{status|DEF Up}}.', 'buff' => ['1019']),
                                 skill('Gain {{status|DEF Up}} and {{status|Veil}}.', 'buff' => %w[1003 1019])]).links
    expect(links).to eq('def up' => '1019', 'veil' => '1003')
  end

  it "doesn't link names named only in conditions, or skills with two names left" do
    links = described_class.new([skill("('''While {{status|Veil}} is in effect:''' …)", 'buff' => ['1003']),
                                 skill('Gain {{status|A}} and {{status|B}}.', 'buff' => %w[1 2])]).links
    expect(links).to be_empty
  end

  it "needs most of a name's votes to agree" do
    skills = ([skill('Gain {{status|Shield}}.', 'buff' => ['1314'])] * 3) + ([skill('Gain {{status|Shield}}.', 'buff' => ['9'])] * 2)
    expect(described_class.new(skills).links).to be_empty
  end

  it 'links to a variant when the votes settle on it, else to the base id' do
    cut = [skill('Gain {{status|40% DMG Cut}}.', 'buff' => ['1019_0_40'])] * 2
    down = [skill('Inflict {{status|DEF Down}}.', 'debuff' => ['1020_13']), skill('Inflict {{status|DEF Down}}.', 'debuff' => ['1020'])]
    expect(described_class.new(cut + down).links).to eq('40% dmg cut' => '1019_0_40', 'def down' => '1020')
  end
end
