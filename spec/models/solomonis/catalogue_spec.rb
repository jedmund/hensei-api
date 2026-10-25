# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Evoking Solomonis catalogues', type: :model do
  describe RaidGroup do
    it 'accepts solomonis or no content mode' do
      expect(build(:raid_group, content_mode: 'solomonis')).to be_valid
      expect(build(:raid_group, content_mode: nil)).to be_valid
      expect(build(:raid_group, content_mode: 'sandbox')).not_to be_valid
    end

    it 'marks its raids as zones' do
      zone = create(:raid, :solomonis_zone)
      expect(zone).to be_solomonis_zone
      expect(create(:raid)).not_to be_solomonis_zone
      expect(Raid.solomonis_zones).to eq([zone])
    end
  end

  describe Character do
    it 'is route-eligible with a zone' do
      evoker = create(:character, :solomonis_evoker)
      plain = create(:character)
      expect(evoker).to be_solomonis_route_eligible
      expect(plain).not_to be_solomonis_route_eligible
      expect(Character.solomonis_route_evokers).to eq([evoker])
      expect(evoker.solomonis_zone.solomonis_evokers).to eq([evoker])
    end
  end

  describe ArcarumBlessing do
    it 'has a single cost limit' do
      expect(ArcarumBlessing::COST_LIMIT).to eq(100)
    end

    it 'orders levels' do
      blessing = create(:arcarum_blessing)
      create(:arcarum_blessing_level, arcarum_blessing: blessing, level: 2)
      create(:arcarum_blessing_level, arcarum_blessing: blessing, level: 1)
      expect(blessing.levels.map(&:level)).to eq([1, 2])
    end

    it 'requires a unique level per blessing' do
      level = create(:arcarum_blessing_level, level: 1)
      expect(build(:arcarum_blessing_level, arcarum_blessing: level.arcarum_blessing, level: 1)).not_to be_valid
    end
  end

  describe PartyBlessing do
    it 'copies the blessing from the level' do
      party_blessing = create(:party_blessing)
      expect(party_blessing.arcarum_blessing).to eq(party_blessing.arcarum_blessing_level.arcarum_blessing)
    end

    it 'rejects a level of another blessing' do
      party_blessing = build(:party_blessing, arcarum_blessing: create(:arcarum_blessing))
      expect(party_blessing).not_to be_valid
    end

    it 'holds one level of each blessing per party' do
      first = create(:party_blessing)
      level = create(:arcarum_blessing_level, arcarum_blessing: first.arcarum_blessing, cost: 10)
      second = build(:party_blessing, party: first.party, arcarum_blessing_level: level)
      expect(second).not_to be_valid
    end

    it 'keeps the total cost within the limit' do
      first = create(:party_blessing, arcarum_blessing_level: create(:arcarum_blessing_level, cost: 70))
      over = build(:party_blessing, party: first.party.reload,
                                    arcarum_blessing_level: create(:arcarum_blessing_level, cost: 40))
      expect(over).not_to be_valid
    end

    it 'is only for Solomonis parties' do
      expect(build(:party_blessing, party: create(:party))).not_to be_valid
    end
  end

  describe SolomonisGuideEffect do
    it 'needs a name in either language' do
      expect(build(:solomonis_guide_effect, name_en: nil, name_jp: '攻撃力')).to be_valid
      expect(build(:solomonis_guide_effect, name_en: nil, name_jp: nil)).not_to be_valid
    end

    it 'enforces a name at the database too' do
      effect = create(:solomonis_guide_effect)
      expect { effect.update_columns(name_en: nil) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'checks rarity, target type and availability' do
      expect(build(:solomonis_guide_effect, rarity: 'legendary')).not_to be_valid
      expect(build(:solomonis_guide_effect, target_type: 'element')).not_to be_valid
      expect(build(:solomonis_guide_effect, availability: 'specialevent')).not_to be_valid
    end

    it 'requires a unique granblue_id' do
      create(:solomonis_guide_effect, granblue_id: 88)
      expect(build(:solomonis_guide_effect, granblue_id: 88)).not_to be_valid
    end

    it 'accepts integer targets and short tags only' do
      expect(build(:solomonis_guide_effect, target_type: 'race', target_values: [2, 8])).to be_valid
      expect(build(:solomonis_guide_effect, type_tags: ['x' * 40])).not_to be_valid
      expect(build(:solomonis_guide_effect, effect_tags: [])).to be_valid
    end
  end

  describe ExpeditionGuideEffect do
    it 'needs a count of at least 1' do
      expect(build(:expedition_guide_effect, count: 0)).not_to be_valid
    end

    it 'holds a non-stackable effect once' do
      effect = create(:solomonis_guide_effect, :unique)
      expect(build(:expedition_guide_effect, solomonis_guide_effect: effect, count: 2)).not_to be_valid
      expect(build(:expedition_guide_effect, solomonis_guide_effect: effect, count: 1)).to be_valid
    end

    it 'allows one inherited effect per party' do
      first = create(:expedition_guide_effect, inherited: true)
      second = build(:expedition_guide_effect, party: first.party, inherited: true)
      expect(second).not_to be_valid
    end

    it 'holds each effect once per party' do
      first = create(:expedition_guide_effect)
      second = build(:expedition_guide_effect, party: first.party,
                                               solomonis_guide_effect: first.solomonis_guide_effect)
      expect(second).not_to be_valid
    end

    it 'is only for Solomonis parties' do
      expect(build(:expedition_guide_effect, party: create(:party))).not_to be_valid
    end
  end
end
