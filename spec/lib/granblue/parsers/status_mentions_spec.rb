# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::StatusMentions do
  def votes(text)
    described_class.in(text).map { |mention| [mention.name, mention.vote] }
  end

  it 'takes the name from the first part that is not a parameter' do
    mention = described_class.in('Inflict {{status|a=10%|Water DEF Lowered|t=3T}} on a foe.').sole
    expect(mention.name).to eq('Water DEF Lowered')
    expect(mention.params).to eq('a' => '10%', 't' => '3T')
  end

  it 'reads gained statuses as buffs, on allies or on foes' do
    expect(votes('All allies gain {{status|DEF Up|t=3T}} and {{status|Veil}}.')).to eq([['DEF Up', 'buff'], ['Veil', 'buff']])
    expect(votes('All foes gain {{status|ATK Up 2|t=2T}}.')).to eq([['ATK Up 2', 'buff']])
  end

  it 'reads inflicted and self-inflicted statuses as debuffs' do
    expect(votes('Inflict {{status|DEF Down|a=25%}} and {{status|Mode Bar Cut}} on a foe.'))
      .to eq([['DEF Down', 'debuff'], ['Mode Bar Cut', 'debuff']])
    expect(votes('Gain {{status|ATK Up}}.<br />Self-inflict {{status|Overheated}}.'))
      .to eq([['ATK Up', 'buff'], ['Overheated', 'debuff']])
  end

  it "reads a level raised on a foe as a debuff" do
    expect(votes("Light damage to a foe.<br />Raise foe's {{status|Tune}} lvl by 1.")).to eq([%w[Tune debuff]])
  end

  it 'gives no vote to a status named in a condition or a removal' do
    text = "('''When {{status|Lucent Refuge}} is in effect:''' Remove {{status|Burned}}. Consumes 1 {{status|Dissolution}}.)"
    expect(votes(text).map(&:last)).to eq([nil, nil, nil])
  end

  it 'reads each clause on its own, so a foe in the previous sentence does not leak' do
    expect(votes('Big Water damage to a foe.<br />Gain 1 {{status|Deluge Crest|t=i}}.')).to eq([['Deluge Crest', 'buff']])
  end

  it 'reads the rest of the clause when the words before name no verb' do
    expect(votes('Sic {{status|Dorrie|t=i}} on a foe.')).to eq([%w[Dorrie debuff]])
    expect(votes('({{status|Utopia|t=5T}} to the [[Field Effect|field]].)')).to eq([%w[Utopia field]])
    expect(votes('Grant {{status|Freigeist}} to another Dark ally.')).to eq([%w[Freigeist buff]])
  end

  it "doesn't take the previous clause for a status that opens one" do
    expect(votes('All allies gain {{status|Charge Boost}}.<br />({{status|Precept Purification}} specs increase.)').last)
      .to eq(['Precept Purification', nil])
  end

  it 'starts a new clause after a condition' do
    text = "'''When a foe has {{tt|Enticed|{{status|Enticed}}<br />{{status|Enticed (Local)}}}}:''' Inflict {{status|Beguile 5}}."
    expect(votes(text).last).to eq(['Beguile 5', 'debuff'])
  end

  it 'says how the text uses each mention' do
    text = "Gain {{status|A}}. Self-inflict {{status|B}}. Inflict {{status|C}}. " \
           "('''When {{status|D}} is in effect:''' …)"
    kinds = described_class.in(text).map(&:kind)
    expect(kinds).to eq(%w[gain self_inflict inflict condition])
  end

  it "doesn't let one skill level's text leak into the next (|des1= ends a clause)" do
    nezahualpilli = '{{InfoDes|num=0|des=Self-inflict {{status|DEF Down}}.|des1=Buff increased to {{status|ATK Up}}.}}'
    sara = '{{InfoDes|num=0|des=Gain {{status|Hostility Boosted}}.|des1=Debuff increased to {{status|ATK Down}}.}}'
    expect(described_class.in(nezahualpilli).map(&:kind)).to eq(%w[self_inflict other])
    expect(described_class.in(sara).map(&:vote)).to eq(['buff', nil])
  end

  it 'keeps a tooltip template with a link in one piece' do
    expect(described_class.in('{{tt|[[Charge Bar]]|text}} Gain {{status|Shield}}.').first.vote).to eq('buff')
  end

  it 'reads the status inside an InfoDes wrapper' do
    text = '{{InfoDes|num=0|des=Gain {{status|Guaranteed TA|t=1T}}.}}'
    expect(votes(text)).to eq([['Guaranteed TA', 'buff']])
  end
end
