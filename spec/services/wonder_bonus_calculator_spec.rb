# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WonderBonusCalculator do
  # The captured bonus lines' values, in order: "+10%" / "＋10％" → 10
  def captured_values(item)
    item['effective_acquired_bonus'].map { |line| WonderCollectionImport.detail_value(line['detail']) }
  end

  def values(bonuses)
    bonuses.map { |bonus| BigDecimal(bonus[:value].to_s) }
  end

  describe 'with the seeded catalogue' do
    before { seed_wonder_catalogue! }

    let(:en_items) { wonder_capture_items('en') }
    let(:ja_items) { wonder_capture_items('ja') }

    %w[9009 9008 9007 9006 9010 9011].each do |granblue_id|
      it "sums Seal #{granblue_id} at level 20 to the captured lines (EN and JA)" do
        wonder = Wonder.find_by!(granblue_id: granblue_id)
        bonuses = described_class.for(wonder, level: 20)

        expect(values(bonuses)).to eq(captured_values(en_items.fetch(granblue_id)))
        expect(values(bonuses)).to eq(captured_values(ja_items.fetch(granblue_id)))
      end
    end

    %w[1001 1002 1003 1004 1005 1006].each do |granblue_id|
      it "sums Yupei #{granblue_id} at level 10 to the captured lines" do
        wonder = Wonder.find_by!(granblue_id: granblue_id)

        expect(values(described_class.for(wonder, level: 10))).to eq(captured_values(en_items.fetch(granblue_id)))
      end
    end

    it 'names Seal stats in first-appearance order with their resistance element' do
      bonuses = described_class.for(Wonder.find_by!(granblue_id: '9008'), level: 20)

      expect(bonuses.pluck(:stat)).to eq(%w[fire_resistance def double_attack_rate healing_cap debuff_resistance
                                            triple_attack_rate debuff_success_rate])
    end

    it 'sums only the levels reached' do
      bonuses = described_class.for(Wonder.find_by!(granblue_id: '9008'), level: 3)

      expect(bonuses).to eq([{ stat: 'fire_resistance', value: 5 }, { stat: 'def', value: 3 },
                             { stat: 'double_attack_rate', value: 3 }])
    end

    it 'names Yupei stats by its element and target' do
      bonuses = described_class.for(Wonder.find_by!(granblue_id: '1004'), level: 10)

      expect(bonuses.pluck(:stat)).to eq(%w[wind_atk def skill_dmg ca_dmg dmg_amplify_vs_earth na_dmg_cap
                                            skill_dmg_cap ca_dmg_cap])
    end

    it 'gives fixed Wonders no computed bonuses' do
      expect(described_class.for(Wonder.find_by!(granblue_id: '9003'))).to eq([])
    end
  end

  describe 'Symbolum Amicitiae' do
    let(:symbolum) { build(:wonder, :symbolum) }

    {
      0 => 0, 299 => 0, 300 => 0.5, 599 => 0.5, 600 => 1, 610 => 1.1, 756 => 2.5, 835 => 3.3,
      900 => 4, 990 => 4.9, 1000 => 5, 2000 => 5
    }.each do |possession, expected|
      it "gives #{expected}% DMG Amplify for #{possession} characters" do
        bonuses = described_class.for(symbolum, possession: possession)

        expect(bonuses).to eq([{ stat: 'dmg_amplify', value: expected }])
      end
    end

    it 'is exact where floats are not (30 steps of 0.1)' do
      expect(described_class.for(symbolum, possession: 900).first[:value]).to be(4)
      expect(described_class.symbolum_tenths(900)).to eq(40)
    end

    it 'gives 0 without a count' do
      expect(described_class.for(symbolum)).to eq([{ stat: 'dmg_amplify', value: 0 }])
    end
  end
end
