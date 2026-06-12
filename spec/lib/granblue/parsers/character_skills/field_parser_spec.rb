# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkills::FieldParser do
  describe '.display_description' do
    it 'collapses nested status/tt templates and strips wikilinks + orphan braces' do
      raw = 'Gain a {{tt|[[Multistrike]]|{{status|Double Strike}}}} effect / {{status|Veil|t=i}}.'
      expect(described_class.display_description(raw)).to eq('Gain a Multistrike effect / Veil.')
    end

    it 'returns nil for blank input' do
      expect(described_class.display_description('')).to be_nil
    end
  end

  describe '.split_top_level' do
    it 'does not split on a pipe inside a wikilink' do
      expect(described_class.split_top_level('des=hungry ([[A#B|pick one]])')).to eq(['des=hungry ([[A#B|pick one]])'])
    end

    it 'splits on top-level pipes but not inside templates' do
      expect(described_class.split_top_level('a=1|b={{x|y}}|c=2')).to eq(['a=1', 'b={{x|y}}', 'c=2'])
    end
  end

  describe '.parse_cooldown' do
    it 'extracts base, enhanced, and initial cooldowns' do
      expect(described_class.parse_cooldown('{{InfoCd|cooldown=8|cooldown1=7|level1=75}}'))
        .to eq(base: 8, enhanced: [7], initial: nil)
      expect(described_class.parse_cooldown('{{ReadyIn|4}}')).to eq(base: nil, enhanced: [], initial: 4)
    end
  end

  describe '.parse_ob_levels' do
    it 'extracts obtained and enhanced levels' do
      expect(described_class.parse_ob_levels('{{InfoOb|obtained=1|enhanced=75|enhanced2=95}}'))
        .to eq(obtained: 1, enhanced: [75, 95])
    end
  end

  describe '.parse_duration_value' do
    it 'parses turn/second durations and the "-" sentinel' do
      expect(described_class.parse_duration_value('{{InfoDur|type=t|duration=3}}')).to eq(value: 3, unit: 'turns')
      expect(described_class.parse_duration_value('{{InfoDur|type=s|duration=180}}')).to eq(value: 180, unit: 'seconds')
      expect(described_class.parse_duration_value('-')).to eq(value: nil, unit: 'none')
    end
  end

  describe '.clean_markup' do
    it 'converts <br>, removes <ref> and bold markup' do
      expect(described_class.clean_markup("a<br />b<ref name=x />''c''")).to eq("a\nbc")
    end
  end

  describe '.parse_info_des' do
    it 'splits des/des1 into an ordered, cleaned description list' do
      result = described_class.parse_info_des('{{InfoDes|num=1|des=Base effect.|des1=Enhanced effect.|level1=95}}')
      expect(result[:descriptions]).to eq(['Base effect.', 'Enhanced effect.'])
    end
  end
end
