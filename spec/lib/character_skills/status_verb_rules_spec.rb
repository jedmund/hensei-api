# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::StatusVerbRules do
  def rule(text)
    Granblue::Parsers::StatusMentions.in(text).last.rule.id
  end

  it 'has unique ids, a plain pattern and an example for every rule' do
    ids = described_class::RULES.map(&:id)
    expect(ids).to eq(ids.uniq)
    expect(described_class::RULES).to all(have_attributes(pattern: be_present, example: be_present))
  end

  it 'reads counters raised on the caster or allies as buffs' do
    expect(rule('Raise {{status|Rev}} level by 1.')).to eq('caster_counter')
    expect(rule("Refill 2 {{status|Hunter's Arrow}}.")).to eq('caster_counter')
    expect(rule('Starts battle with 3 {{status|Bridal Bullet}} (Max: 12).')).to eq('starts_battle')
    expect(rule('{{status|Body Heat}} lvl rises by 1.')).to eq('counter_rises')
    expect(rule('Switch to {{status|Supplication}} mode.')).to eq('switch_to')
    expect(rule('Begin battle with {{status|Glimmering Attire}}.')).to eq('starts_battle')
  end

  it 'reads counters raised on foes, and things set on a foe, as debuffs' do
    expect(rule("Raise all foes' {{status|Tuning}} lvl by 1.")).to eq('foe_counter')
    expect(rule('Set a {{status|Flower Bud}} on a foe.')).to eq('set_on_foe')
  end

  it 'gives no vote to spending a counter or naming it in a condition' do
    expect(rule('Consumes 1 {{status|Dissolution}}.')).to eq('consume')
    expect(rule("('''When {{status|Lucent Refuge}} is in effect:''' …)")).to eq('condition')
    expect(Granblue::Parsers::StatusMentions.in('Consumes 1 {{status|Dissolution}}.').first.vote).to be_nil
  end

  describe 'caster_counter sub-rules (D44)' do
    def match(text, listed: nil)
      described_class.match(text.downcase, '', listed).id
    end

    it 'gives no vote to a counter that is counted or checked after the verb' do
      expect(match("Restore all allies' HP based on Diantha's ")).to eq('counter_checked')
      expect(match('Restore HP to allies with ')).to eq('counter_checked')
      expect(described_class.match('restore hp to allies with ', '').category).to be_nil
    end

    it 'gives no vote to a counter the wiki list files under debuffs (it sits on a foe)' do
      expect(match('Raise ', listed: 'debuff')).to eq('foe_held_counter')
      expect(described_class.match('raise ', '', 'debuff').category).to be_nil
      expect(match('Raise ', listed: 'buff')).to eq('caster_counter')
    end

    it 'reads the list table through the mention' do
      Granblue::Parsers::StatusList.use(File.read(Rails.root.join('spec/fixtures/wiki/status_list_extract.lua')))
      expect(rule('Raise {{status|Blinded}} lvl by 1 (Max: 10).')).to eq('foe_held_counter')
      expect(rule('Raise {{status|Rev}} lvl by 1.')).to eq('caster_counter')
    ensure
      Granblue::Parsers::StatusList.reset!
    end
  end

  it 'reads immunity to a status as naming a debuff' do
    expect(rule('Immune to {{status|Poisoned}}.')).to eq('immune')
    expect(Granblue::Parsers::StatusMentions.in('Immunity to {{status|Charmed}}.').first.vote).to eq('debuff')
    expect(rule('When immune, gain {{status|Shield}}.')).to eq('gain')
  end

  it 'lets an apply verb after the condition word decide' do
    expect(rule('If successful, inflict {{status|Paralyzed}}.')).to eq('inflict')
    expect(rule('If successful, all allies gain {{status|Shield}}.')).to eq('gain')
    expect(rule('Upon dodging, gain {{status|Charged}} next turn.')).to eq('gain')
    expect(rule("When a foe has {{status|Beguile}} at end of turn: …")).to eq('condition')
  end

  it 'keeps the earlier rules: self-inflict, inflict, gain, field' do
    expect(%w[Self-inflict Inflict Gain].map { |verb| rule("#{verb} {{status|X}}.") }).to eq(%w[self_inflict inflict gain])
    expect(rule('({{status|Utopia}} to the [[Field Effect|field]].)')).to eq('to_the_field')
  end
end
