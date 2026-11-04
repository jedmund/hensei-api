# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CollectionItemQuery do
  let(:owner) { create(:user, language: 'en') }
  let(:weapons) { Api::V1::CollectionWeaponsController.item_type }
  let(:summons) { Api::V1::CollectionSummonsController.item_type }
  let(:characters) { Api::V1::CollectionCharactersController.item_type }

  def query(item_type, viewer: owner, **params)
    described_class.new(item_type, owner: owner, params: ActionController::Parameters.new(params), viewer: viewer)
  end

  describe 'item types' do
    it 'are frozen all the way down' do
      expect(weapons).to be_frozen
      expect(weapons.permitted).to be_frozen
      expect(weapons.owned_includes.first).to be_frozen
      expect(characters.permitted.last[:ring1]).to be_frozen
    end
  end

  describe '#owned' do
    it 'lists only the owner\'s items' do
      mine = create(:collection_weapon, user: owner)
      create(:collection_weapon)

      expect(query(weapons).owned).to contain_exactly(mine)
    end

    it 'matches any of several comma-separated values' do
      fire = create(:collection_weapon, user: owner, weapon: create(:weapon, element: 1))
      water = create(:collection_weapon, user: owner, weapon: create(:weapon, element: 4))
      create(:collection_weapon, user: owner, weapon: create(:weapon, element: 3))

      expect(query(weapons, element: '1,4').owned).to contain_exactly(fire, water)
    end

    it 'applies a filter given as a blank param' do
      create(:collection_weapon, user: owner)

      expect(query(weapons, element: '').owned).to be_empty
    end

    it 'calls a type scope with the split values' do
      sabre = create(:collection_weapon, user: owner, weapon: create(:weapon, proficiency: 1))
      create(:collection_weapon, user: owner, weapon: create(:weapon, proficiency: 2))

      expect(query(weapons, proficiency: '1').owned).to contain_exactly(sabre)
    end

    it 'passes an exact filter through unsplit' do
      kept = create(:collection_weapon, user: owner)
      create(:collection_weapon, user: owner)

      expect(query(weapons, weapon_id: kept.weapon_id).owned).to contain_exactly(kept)
    end

    it 'applies a flag filter only when the param is true' do
      eligible = create(:collection_summon, user: owner, summon: create(:summon, support_eligible: true))
      ineligible = create(:collection_summon, user: owner, summon: create(:summon, support_eligible: false))

      expect(query(summons, support_eligible: 'true').owned).to contain_exactly(eligible)
      expect(query(summons, support_eligible: 'false').owned).to contain_exactly(eligible, ineligible)
    end

    it 'searches and sorts by name in the viewer\'s language' do
      viewer = create(:user, language: 'ja')
      first = create(:collection_weapon, user: owner, weapon: create(:weapon, name_en: 'Zzz Probe', name_jp: 'あ'))
      last = create(:collection_weapon, user: owner, weapon: create(:weapon, name_en: 'Aaa Probe', name_jp: 'ん'))
      create(:collection_weapon, user: owner, weapon: create(:weapon, name_en: 'Other'))

      expect(query(weapons, viewer: viewer, search: 'probe', sort: 'name_asc').owned.to_a).to eq([first, last])
    end
  end

  describe '#unowned' do
    it 'lists catalog rows the owner has no copy of' do
      owned = create(:weapon, name_en: 'Owned Probe')
      unowned = create(:weapon, name_en: 'Unowned Probe')
      create(:collection_weapon, user: owner, weapon: owned)
      create(:collection_weapon, user: owner, weapon: owned)

      expect(query(weapons, search: 'Probe').unowned).to contain_exactly(unowned)
    end

    it 'matches a column filter' do
      series = create(:weapon_series)
      match = create(:weapon, name_en: 'Match Probe', weapon_series: series)
      create(:weapon, name_en: 'Other Probe')

      expect(query(weapons, search: 'Probe', series: series.id.to_s).unowned).to contain_exactly(match)
    end

    it 'matches when either of two columns does' do
      first = create(:character, name_en: 'First Probe', race1: 2)
      second = create(:character, name_en: 'Second Probe', race1: 1, race2: 2)
      create(:character, name_en: 'Neither Probe', race1: 3)

      expect(query(characters, search: 'Probe', race: '2').unowned).to contain_exactly(first, second)
    end

    it 'calls a catalog scope filter' do
      series = create(:character_series)
      member = create(:character, name_en: 'Member Probe')
      create(:character_series_membership, character: member, character_series: series)
      create(:character, name_en: 'Other Probe')

      expect(query(characters, search: 'Probe', series: series.id.to_s).unowned).to contain_exactly(member)
    end

    it 'applies a flag filter as a true column' do
      eligible = create(:summon, name_en: 'Eligible Probe', support_eligible: true)
      create(:summon, name_en: 'Ineligible Probe', support_eligible: false)

      expect(query(summons, search: 'Probe', support_eligible: '1').unowned).to contain_exactly(eligible)
    end

    it 'sorts by the type\'s proficiency column' do
      spear = create(:character, name_en: 'Spear Probe', proficiency1: 4)
      dagger = create(:character, name_en: 'Dagger Probe', proficiency1: 2)

      expect(query(characters, search: 'Probe', sort: 'proficiency_desc').unowned.to_a).to eq([spear, dagger])
    end

    it 'falls back to newest first for a sort the type lacks' do
      old = create(:summon, name_en: 'Old Probe', release_date: 3.years.ago, flb_date: nil)
      new = create(:summon, name_en: 'New Probe', release_date: 1.month.ago, flb_date: nil)

      expect(query(summons, search: 'Probe', sort: 'proficiency_asc').unowned.to_a).to eq([new, old])
    end

    it 'sorts names in the viewer\'s language' do
      viewer = create(:user, language: 'ja')
      first = create(:summon, name_en: 'Zzz Probe', name_jp: 'あ')
      last = create(:summon, name_en: 'Aaa Probe', name_jp: 'ん')

      expect(query(summons, viewer: viewer, search: 'Probe', sort: 'name_asc').unowned.to_a).to eq([first, last])
      expect(query(summons, viewer: nil, search: 'Probe', sort: 'name_asc').unowned.to_a).to eq([last, first])
    end
  end
end
