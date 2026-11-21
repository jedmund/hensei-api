# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261121110001_mark_unite_and_fight_raid_group').to_s

RSpec.describe 'Wonders data migrations' do
  describe 'LoadWonderCatalogue' do
    it 'seeds the catalogue and is rerunnable' do
      seed_wonder_catalogue!
      counts = [WonderCategory, Wonder, WonderEffect, WonderEffectLink, WonderLevelBonus, WonderEvolutionCap].map(&:count)
      seed_wonder_catalogue!

      expect([WonderCategory, Wonder, WonderEffect, WonderEffectLink, WonderLevelBonus, WonderEvolutionCap].map(&:count))
        .to eq(counts)
      expect(counts.first(2)).to eq([7, 57])
      expect(WonderLevelBonus.count).to eq((6 * 20) + (6 * 10))
      expect(WonderEvolutionCap.count).to eq(24)
    end

    it 'sets kinds, elements and the battle-relevant list' do
      seed_wonder_catalogue!

      expect(Wonder.where(kind: 'leveled').count).to eq(12)
      expect(Wonder.where(kind: 'scaling').pluck(:granblue_id)).to eq(['9015'])
      expect(Wonder.find_by!(granblue_id: '2003').element).to eq(6)
      expect(Wonder.find_by!(granblue_id: '9013').element).to be_nil
      expect(Wonder.where(battle_relevant: true).pluck(:granblue_id))
        .to match_array(%w[9009 9008 9007 9006 9010 9011 1001 1002 1003 1004 1005 1006 9003 9013 9014 9015
                           9016 9017 29 2001 2002 2003 2004 2005])
      expect(Wonder.where(hidden_in_unite_and_fight: true).count).to eq(6)
    end

    it 'shares effects by action_id' do
      seed_wonder_catalogue!

      kiln = Wonder.find_by!(granblue_id: '9').wonder_effects.first
      expect(Wonder.find_by!(granblue_id: '13').wonder_effects.first).to eq(kiln)
    end

    it 'updates changed rows in place' do
      seed_wonder_catalogue!
      wonder = Wonder.find_by!(granblue_id: '9008')
      wonder.update!(name_en: 'Edited')
      wonder.level_bonuses.find_by!(level: 1).update!(value: 99)

      seed_wonder_catalogue!

      expect(wonder.reload.name_en).to eq('Seal of the Underworld Emperor')
      expect(wonder.level_bonuses.find_by!(level: 1).value).to eq(5)
    end
  end

  describe 'MarkUniteAndFightRaidGroup' do
    it 'marks the group named Unite and Fight' do
      group = create(:raid_group, name_en: 'Unite and Fight', section: 2)
      other = create(:raid_group)

      ActiveRecord::Migration.suppress_messages { MarkUniteAndFightRaidGroup.new.up }

      expect(group.reload.content_mode).to eq('unite_and_fight')
      expect(group).to be_unite_and_fight
      expect(other.reload.content_mode).to be_nil
    end

    it 'does nothing when the group is absent' do
      expect { ActiveRecord::Migration.suppress_messages { MarkUniteAndFightRaidGroup.new.up } }
        .not_to raise_error
    end
  end
end
