# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GridDamage::GridComposition do
  describe '.summarize' do
    it 'tallies weapon types, series, per-id copies, distinct skill types, and omega-skill count' do
      entries = [
        { proficiency: 1, series_slug: 'epic', granblue_id: 'A', modifiers: %w[Might Enmity], omega: false },
        { proficiency: 1, series_slug: 'epic', granblue_id: 'A', modifiers: %w[Might], omega: true },
        { proficiency: 2, series_slug: 'militis', granblue_id: 'B', modifiers: %w[Stamina], omega: false }
      ]
      r = described_class.summarize(entries)
      expect(r[:weapon_type_counts]).to eq(1 => 2, 2 => 1)
      expect(r[:weapon_series_counts]).to eq('epic' => 2, 'militis' => 1)
      expect(r[:id_counts]).to eq('A' => 2, 'B' => 1)
      expect(r[:distinct_weapon_type_count]).to eq(2)
      expect(r[:max_weapon_type_count]).to eq(2)
      expect(r[:skill_type_count]).to eq(3) # Might, Enmity, Stamina (deduped)
      expect(r[:omega_skill_count]).to eq(1)
    end

    it 'tallies omega-skill weapons per element' do
      entries = [
        { proficiency: 1, granblue_id: 'A', modifiers: [], omega: true, element: 'fire' },
        { proficiency: 1, granblue_id: 'B', modifiers: [], omega: true, element: 'earth' },
        { proficiency: 1, granblue_id: 'C', modifiers: [], omega: true, element: 'earth' }
      ]
      expect(described_class.summarize(entries)[:omega_skill_counts_by_element]).to eq('fire' => 1, 'earth' => 2)
    end

    it 'tallies each series per element' do
      entries = [
        { proficiency: 1, series_slug: 'odious', granblue_id: 'A', modifiers: [], element: 'water' },
        { proficiency: 1, series_slug: 'odious', granblue_id: 'B', modifiers: [], element: 'water' },
        { proficiency: 1, series_slug: 'odious', granblue_id: 'C', modifiers: [], element: 'fire' }
      ]
      expect(described_class.summarize(entries)[:weapon_series_counts_by_element])
        .to eq(%w[odious water] => 2, %w[odious fire] => 1)
    end
  end

  describe '.count_for_basis' do
    let(:series) { instance_double(WeaponSeries, slug: 'epic') }
    let(:weapon) { instance_double(Weapon, proficiency: 1, weapon_series: series, element: 1) }
    let(:composition) do
      {
        weapon_type_counts: { 1 => 3 },
        max_weapon_type_count: 4,
        distinct_weapon_type_count: 2,
        weapon_series_counts: { 'epic' => 2 },
        omega_skill_count: 6
      }
    end

    # 6C5bN9: Iron's Vivification counts Fire omega weapons only, not Earth Lifetree's.
    it "counts only the bearing weapon's element's omega weapons" do
      by_element = composition.merge(omega_skill_counts_by_element: { 'fire' => 4, 'earth' => 3 })
      expect(described_class.count_for_basis('omega_skill', weapon: weapon, composition: by_element)).to eq(4)
    end

    # h6sAVJ: Allowater's Vitiation counts Water Taboo weapons only
    it "counts the bearing weapon's series in its own element" do
      odious = instance_double(WeaponSeries, slug: 'odious')
      water = instance_double(Weapon, proficiency: 1, weapon_series: odious, element: 2)
      counts = composition.merge(weapon_series_counts_by_element: { %w[odious water] => 7, %w[odious fire] => 2 })
      expect(described_class.count_for_basis('same_element_series', weapon: water, composition: counts)).to eq(7)
    end

    it 'resolves canonical count bases' do
      expect(described_class.count_for_basis('same_weapon_type', weapon: weapon, composition: composition)).to eq(3)
      expect(described_class.count_for_basis('max_same_weapon_type', weapon: weapon, composition: composition)).to eq(4)
      expect(described_class.count_for_basis('distinct_weapon_types', weapon: weapon, composition: composition)).to eq(2)
      expect(described_class.count_for_basis('same_series', weapon: weapon, composition: composition)).to eq(2)
      expect(described_class.count_for_basis('series:epic', weapon: weapon, composition: composition)).to eq(2)
      expect(described_class.count_for_basis('omega_skill', weapon: weapon, composition: composition)).to eq(6)
    end

    it "counts the crew's races, including the MC" do
      effect = double(condition: { 'races' => %w[1 3] })
      crew = composition.merge(character_races: [1, 3, '3', 2, nil])

      expect(described_class.count_for_basis('crew_races', weapon: weapon, composition: crew, effect: effect)).to eq(3)
      expect(described_class.count_for_basis('crew_races', weapon: weapon, composition: composition, effect: effect)).to eq(0)
      expect(described_class.count_for_basis('crew_races', weapon: weapon, composition: crew)).to eq(0)
    end

    it 'counts nothing for a missing weapon or series' do
      expect(described_class.count_for_basis('same_weapon_type', weapon: nil, composition: composition)).to eq(0)
      expect(described_class.count_for_basis('same_series', weapon: nil, composition: composition)).to eq(0)
      expect(described_class.count_for_basis('same_element_series', weapon: nil, composition: composition)).to eq(0)
      expect(described_class.count_for_basis('series:militis', weapon: weapon, composition: composition)).to eq(0)
      expect(described_class.count_for_basis('max_same_weapon_type', weapon: weapon, composition: {})).to eq(0)
    end

    it 'falls back to the grid-wide omega count without a weapon element' do
      by_element = composition.merge(omega_skill_counts_by_element: { 'fire' => 4 })
      elementless = instance_double(Weapon, proficiency: 1, weapon_series: series, element: nil)

      expect(described_class.count_for_basis('omega_skill', weapon: elementless, composition: by_element)).to eq(6)
      expect(described_class.count_for_basis('omega_skill', weapon: nil, composition: {})).to eq(0)
    end

    it 'rejects legacy and unsupported count bases' do
      %w[weapon_type group:arbitrary].each do |basis|
        expect do
          described_class.count_for_basis(basis, weapon: weapon, composition: composition)
        end.to raise_error(ArgumentError, /Unknown count_basis/)
      end
    end
  end

  describe '.valid_count_condition?' do
    it 'accepts positive canonical thresholds' do
      condition = { 'type' => 'count_basis_gte', 'basis' => 'distinct_weapon_types', 'gte' => 10 }

      expect(described_class.valid_count_condition?(condition)).to be(true)
    end

    it 'rejects legacy types, nonpositive thresholds, and obsolete all flags' do
      conditions = [
        { 'type' => 'weapon_group_count', 'gte' => 0, 'all' => true },
        { 'type' => 'count_basis_gte', 'basis' => 'distinct_weapon_types', 'gte' => 0 },
        { 'type' => 'count_basis_gte', 'basis' => 'distinct_weapon_types', 'gte' => 10, 'all' => true }
      ]

      expect(conditions).to all(satisfy { |condition| !described_class.valid_count_condition?(condition) })
    end
  end
end
