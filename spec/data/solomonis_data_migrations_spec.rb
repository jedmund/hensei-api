# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261012100001_create_evoking_solomonis_zone')
require Rails.root.join('db/data/20261012100002_assign_solomonis_evoker_zones')
require Rails.root.join('db/data/20261012100003_load_solomonis_blessings')
require Rails.root.join('db/data/20261012100004_load_solomonis_guide_effects')

RSpec.describe 'Evoking Solomonis data migrations' do
  def quietly(migration)
    migration.verbose = false
    migration.up
  end

  describe CreateEvokingSolomonisZone do
    it 'creates the group and both zones, rerunnably' do
      2.times { quietly(described_class.new) }

      group = RaidGroup.find_by!(content_mode: 'solomonis')
      expect(group).to have_attributes(name_en: 'Evoking Solomonis', name_jp: 'Evoking Solomonis', section: 3)
      expect(group.raids.pluck(:slug)).to contain_exactly('allotropic-microcosm', 'paracyclic-microcosm')
      expect(Raid.find_by!(slug: 'allotropic-microcosm'))
        .to have_attributes(name_en: 'Allotropic Microcosm', name_jp: nil, player_count: 1, element: 0)
      expect(Raid.find_by!(slug: 'paracyclic-microcosm')).to have_attributes(name_en: 'Paracyclic Microcosm')
    end

    it 'keeps names edited by hand' do
      quietly(described_class.new)
      RaidGroup.find_by!(content_mode: 'solomonis').update!(name_jp: 'ソロモニス')
      quietly(described_class.new)
      expect(RaidGroup.find_by!(content_mode: 'solomonis').name_jp).to eq('ソロモニス')
    end
  end

  describe AssignSolomonisEvokerZones do
    before { quietly(CreateEvokingSolomonisZone.new) }

    def character(granblue_id, **attrs)
      Character.find_by(granblue_id: granblue_id) || create(:character, granblue_id: granblue_id, **attrs)
    end

    it 'gives each of the ten Evokers its zone by granblue_id only' do
      evokers = described_class::EVOKERS.keys.index_with { |id| character(id) }
      alternate = character('3040546000', name_en: 'Nier')

      2.times { quietly(described_class.new) }

      described_class::EVOKERS.each do |id, (_name, _element, zone_slug)|
        expect(evokers[id].reload.solomonis_zone).to eq(Raid.find_by!(slug: zone_slug))
      end
      expect(alternate.reload.solomonis_zone_id).to be_nil
      expect(Character.solomonis_route_evokers.count).to eq(10)
    end

    it 'skips a missing Evoker' do
      Character.where(granblue_id: '3040164000').delete_all
      expect { quietly(described_class.new) }.not_to raise_error
    end
  end

  describe LoadSolomonisBlessings do
    it 'loads the seed, rerunnably' do
      2.times { quietly(described_class.new) }

      expect(ArcarumBlessing.count).to eq(10)
      expect(ArcarumBlessing.ordered.pluck(:slug)).to eq(ArcarumBlessing::SLUGS)
      justice = ArcarumBlessing.find_by!(slug: 'justice')
      expect(justice).to be_released
      expect(justice.levels.map(&:cost)).to eq([70, 60, 50])
      expect(ArcarumBlessing.find_by!(slug: 'tower')).not_to be_released
    end

    it 'never overwrites values already in the database' do
      quietly(described_class.new)
      level = ArcarumBlessing.find_by!(slug: 'death').levels.first
      level.update!(description_jp: '手入力', cost: 45)
      quietly(described_class.new)
      expect(level.reload).to have_attributes(description_jp: '手入力', cost: 45)
    end
  end

  describe LoadSolomonisGuideEffects do
    it 'loads the seed and resolves Evoker effects, rerunnably' do
      fraux = Character.find_by(granblue_id: '3040161000') || create(:character, granblue_id: '3040161000')
      2.times { quietly(described_class.new) }

      seed = JSON.parse(File.read(described_class::SEED_PATH))['guide_effects']
      expect(SolomonisGuideEffect.count).to eq(seed.size)
      effect = SolomonisGuideEffect.find_by!(granblue_id: 107)
      expect(effect).to have_attributes(rarity: 'unique', stackable: false, target_type: 'character',
                                        target_values: [3100], character_id: fraux.id)
    end

    it 'fills missing values but keeps hand edits' do
      quietly(described_class.new)
      effect = SolomonisGuideEffect.find_by!(granblue_id: 1)
      effect.update!(name_en: 'Edited', availability: nil)
      quietly(described_class.new)
      expect(effect.reload.name_en).to eq('Edited')
      expect(effect.availability).to eq('global')
    end
  end
end
