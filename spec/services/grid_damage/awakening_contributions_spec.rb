# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::AwakeningContributions do
  def add_awakened_weapon(party:, name:, series_slug:, awakening_slug:, level:, mainhand: false, proficiency: 1)
    series = WeaponSeries.find_or_create_by!(slug: series_slug) do |weapon_series|
      weapon_series.name_en = series_slug.titleize
      weapon_series.name_jp = series_slug
      weapon_series.has_awakening = true
    end
    awakening = Awakening.find_or_create_by!(slug: awakening_slug, object_type: "Weapon") do |record|
      record.name_en = "Test Awakening"
      record.name_jp = "覚醒"
    end
    weapon = create(:weapon, name_en: name, weapon_series: series, proficiency: proficiency)
    position = mainhand ? -1 : party.weapons.count
    create(:grid_weapon, party: party, weapon: weapon, awakening: awakening,
                         awakening_level: level, position: position)
  end

  def values_for(party, composition: { mc_specialties: %w[sabre dagger] })
    described_class.for_party(party, composition: composition)
                   .each_with_object(Hash.new { |h, k| h[k] = Hash.new(0.0) }) do |contribution, values|
      values[contribution.boost_type][contribution.series] += contribution.value
    end
  end

  it "uses the Proven Weapons awakening tables instead of the generic Grand table" do
    attack = create(:party)
    add_awakened_weapon(party: attack, name: "Ushumgal", series_slug: "proven",
                        awakening_slug: "weapon-atk", level: 15)
    defense = create(:party)
    add_awakened_weapon(party: defense, name: "Clarion", series_slug: "proven",
                        awakening_slug: "weapon-def", level: 15)
    special = create(:party)
    add_awakened_weapon(party: special, name: "Daur da Blao", series_slug: "proven",
                        awakening_slug: "weapon-special", level: 15)

    attack_values = values_for(attack)
    defense_values = values_for(defense)
    special_values = values_for(special)

    expect(attack_values["atk"]["ex"]).to eq(15.0)
    expect(defense_values["def"][nil]).to eq(20.0)
    expect(special_values["skill_dmg_cap"][nil]).to eq(5.0)
    expect(special_values["dmg_cap"][nil]).to eq(3.0)
    expect(special_values["atk"]).to be_empty
    expect(special_values["hp"]).to be_empty
  end

  it "applies World awakening bonuses only for the weapon's specialty pair" do
    party = create(:party)
    add_awakened_weapon(party: party, name: "Worldscathing Leon", series_slug: "world",
                        awakening_slug: "weapon-special", level: 10)

    matching = values_for(party, composition: { mc_specialties: %w[gun dagger] })
    nonmatching = values_for(party, composition: { mc_specialties: %w[staff sabre] })

    expect(matching["atk"]["ex"]).to eq(10.0)
    expect(matching["hp"][nil]).to eq(10.0)
    expect(matching["na_dmg_cap"][nil]).to eq(10.0)
    expect(nonmatching).to be_empty
  end

  it "covers the remaining World cap-table variants" do
    party = create(:party)
    add_awakened_weapon(party: party, name: "Worldbreaking Tauros", series_slug: "world",
                        awakening_slug: "weapon-special", level: 10)
    add_awakened_weapon(party: party, name: "Worldforging Moros", series_slug: "world",
                        awakening_slug: "weapon-special", level: 10)

    values = values_for(party, composition: { mc_specialties: %w[melee bow] })

    expect(values["skill_dmg_cap"][nil]).to eq(20.0)
    expect(values["ca_dmg_cap"][nil]).to eq(20.0)
    expect(values["atk"]["ex"]).to eq(20.0)
    expect(values["hp"][nil]).to eq(20.0)
  end

  it "uses Exo attack awakening group variants only on mapped mainhands" do
    expectations = {
      "Exo Ashavan" => ["ca_supp", 300_000.0],
      "Exo Hamartia" => ["dmg_supp", 30_000.0],
      "Exo Kshathra" => ["na_dmg_cap", 10.0],
      "Exo Australis" => ["skill_dmg_cap", 15.0]
    }

    expectations.each do |weapon_name, (boost_type, expected_value)|
      party = create(:party)
      add_awakened_weapon(party: party, name: weapon_name, series_slug: "exo",
                          awakening_slug: "weapon-atk", level: 10, mainhand: true)

      values = values_for(party)

      expect(values["atk"]["ex"]).to eq(20.0)
      expect(values["dmg_cap"][nil]).to eq(10.0)
      expect(values[boost_type][nil]).to eq(expected_value)
    end
  end

  it "does not guess an Exo attack awakening table for unmapped names or non-mainhands" do
    party = create(:party)
    add_awakened_weapon(party: party, name: "Exo Future Unknown", series_slug: "exo",
                        awakening_slug: "weapon-atk", level: 10, mainhand: true)
    add_awakened_weapon(party: party, name: "Exo Australis", series_slug: "exo",
                        awakening_slug: "weapon-atk", level: 10, mainhand: false)

    expect(values_for(party)).to be_empty
  end

  it "maps every Exo attack variant named by the wiki template" do
    expected_groups = {
      "ca_supp" => %w[Exo\ Ashavan Exo\ Ephialtes],
      "dmg_supp" => %w[Exo\ Antaeus Exo\ Hamartia Exo\ Heliocentrum],
      "na_dmg_cap" => ["Exo Kshathra", "Exo Maitrah Karuna", "Exo Pelion"],
      "skill_dmg_cap" => ["Exo Australis", "Exo Aristarchus", "Exo Krodha", "Exo Evilenes"]
    }

    expected_groups.each do |boost_type, weapon_names|
      weapon_names.each do |weapon_name|
        party = create(:party)
        add_awakened_weapon(party: party, name: weapon_name, series_slug: "exo",
                            awakening_slug: "weapon-atk", level: 10, mainhand: true)

        expect(values_for(party)[boost_type][nil]).to be_positive
      end
    end
  end
end
