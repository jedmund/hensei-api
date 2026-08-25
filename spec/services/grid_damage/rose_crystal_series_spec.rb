# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rose Crystal series data" do
  ROSE_WEAPONS = [ # rubocop:disable Lint/ConstantDefinitionInBlock
    { id: "1040307000", name: "Rose Crystal Axe", element: 1, profile: :brier,
      first: "Emerald Rose Brier", first_desc: "Medium boost to wind allies' ATK and max HP",
      second: "Emerald Rose Bud", second_desc: "Lessen fire DMG taken for wind allies",
      reduced_element: "fire" },
    { id: "1040706100", name: "Rose Crystal Bow", element: 2, profile: :brier,
      first: "Blood Rose Brier", first_desc: "Medium boost to Fire allies' ATK and max HP",
      second: "Blood Rose Bud", second_desc: "Lessen Water DMG taken for Fire allies",
      reduced_element: "water" },
    { id: "1040607400", name: "Rose Crystal Claw", element: 4, profile: :brier,
      first: "Bronze Rose Brier", first_desc: "Medium boost to Earth allies' ATK and max HP",
      second: "Bronze Rose Bud", second_desc: "Lessen Wind DMG taken for Earth allies",
      reduced_element: "wind" },
    { id: "1040806300", name: "Rose Crystal Harp", element: 3, profile: :brier,
      first: "Ice Rose Brier", first_desc: "Medium boost to Water allies' ATK and max HP",
      second: "Ice Rose Bud", second_desc: "Lessen Earth DMG taken for Water allies",
      reduced_element: "earth" },
    { id: "1040108400", name: "Rose Crystal Knife", element: 1, profile: :thorns,
      first: "Emerald Rose Thorns", first_desc: "Big boost to wind allies' ATK",
      second: "Emerald Rose Barrier", second_desc: "Lessen earth DMG for all allies",
      reduced_element: "earth" },
    { id: "1040207200", name: "Rose Crystal Lance", element: 4, profile: :thorns,
      first: "Bronze Rose Thorns", first_desc: "Big boost to Earth allies' ATK",
      second: "Bronze Rose Barrier", second_desc: "Lessen Water DMG for all allies",
      reduced_element: "water" },
    { id: "1040009700", name: "Rose Crystal Sword", element: 3, profile: :thorns,
      first: "Ice Rose Thorns", first_desc: "Big boost to Water allies' ATK",
      second: "Ice Rose Barrier", second_desc: "Lessen Fire DMG for all allies",
      reduced_element: "fire" },
    { id: "1040409500", name: "Rose Crystal Wand", element: 2, profile: :thorns,
      first: "Blood Rose Thorns", first_desc: "Big boost to Fire allies' ATK",
      second: "Blood Rose Barrier", second_desc: "Lessen Wind DMG for all allies",
      reduced_element: "wind" }
  ].freeze

  let!(:rose_series) do
    WeaponSeries.find_by(slug: "rose") || create(:weapon_series, slug: "rose", name_en: "Rose Weapons")
  end

  before do
    create(:weapon_skill_boost_type, :multiplicative, key: "atk") unless WeaponSkillBoostType.exists?(key: "atk")
    create(:weapon_skill_boost_type, :defensive, key: "hp", grid_cap: 400) unless WeaponSkillBoostType.exists?(key: "hp")
    unless WeaponSkillBoostType.exists?(key: "elem_reduc")
      create(:weapon_skill_boost_type, :defensive, key: "elem_reduc", grid_cap: 30)
    end

    ROSE_WEAPONS.each { |attrs| seed_rose_weapon(attrs) }
    CurateRoseCrystalSeriesValues.new.up
  end

  def seed_rose_weapon(attrs)
    weapon = create(
      :weapon,
      granblue_id: attrs.fetch(:id),
      name_en: attrs.fetch(:name),
      element: attrs.fetch(:element),
      max_skill_level: 10,
      weapon_series: rose_series
    )
    first_slot = create(:weapon_skill, weapon: weapon, position: 0)
    first_version = create(
      :weapon_skill_version,
      weapon_skill: first_slot,
      skill: create(:skill, name_en: attrs.fetch(:first), description_en: attrs.fetch(:first_desc)),
      ordinal: 0,
      skill_series: "ex",
      skill_size: attrs.fetch(:profile) == :brier ? "medium" : "big"
    )
    generated_rows(attrs).each do |boost_type, anchors|
      create(
        :weapon_skill_datum,
        weapon_skill_version: first_version,
        modifier: attrs.fetch(:first),
        boost_type: boost_type,
        series: "ex",
        size: first_version.skill_size,
        sl1: anchors[0],
        sl10: anchors[1],
        sl15: anchors[2],
        aura_boostable: false
      )
    end

    second_slot = create(:weapon_skill, weapon: weapon, position: 1)
    create(
      :weapon_skill_version,
      weapon_skill: second_slot,
      skill: create(:skill, name_en: attrs.fetch(:second), description_en: attrs.fetch(:second_desc)),
      ordinal: 0,
      skill_series: "ex"
    )
  end

  def generated_rows(attrs)
    if attrs.fetch(:profile) == :brier
      { "atk" => [3.6, 14.4, 17.4], "hp" => [7.2, 18.0, 20.4] }
    else
      { "atk" => [7.2, 18.0, 21.6] }
    end
  end

  def boosts_for(granblue_id, skill_level: 10)
    party = create(:party)
    weapon = Weapon.find_by!(granblue_id: granblue_id)
    create(:grid_weapon, party: party, weapon: weapon, position: 0,
                         uncap_level: 3, skill_level: skill_level)

    GridDamage::Calculator.boost_list(party)
  end

  it "applies the Brier and Bud profile to every matching weapon" do
    ROSE_WEAPONS.select { |attrs| attrs.fetch(:profile) == :brier }.each do |attrs|
      boosts = boosts_for(attrs.fetch(:id))

      expect(boosts.fetch("atk").by_series.fetch("ex")).to eq(12.0)
      expect(boosts.fetch("hp").total).to eq(12.0)
      expect(boosts.fetch("#{attrs.fetch(:reduced_element)}_reduc").total).to eq(20.0)
    end
  end

  it "applies the Thorns and Barrier profile to every matching weapon" do
    ROSE_WEAPONS.select { |attrs| attrs.fetch(:profile) == :thorns }.each do |attrs|
      boosts = boosts_for(attrs.fetch(:id))

      expect(boosts.fetch("atk").by_series.fetch("ex")).to eq(15.0)
      expect(boosts).not_to have_key("hp")
      expect(boosts.fetch("#{attrs.fetch(:reduced_element)}_reduc").total).to eq(10.0)
    end
  end

  it "keeps different reduction elements separate in one grid" do
    party = create(:party)
    %w[1040706100 1040409500].each_with_index do |granblue_id, position|
      create(:grid_weapon, party: party, weapon: Weapon.find_by!(granblue_id: granblue_id),
                           position: position, uncap_level: 3, skill_level: 10)
    end

    boosts = GridDamage::Calculator.boost_list(party)
    lines = GridDamage::PanelPresenter.present(party).fetch(:lines).index_by { |line| line.fetch(:key) }

    expect(boosts.fetch("water_reduc").total).to eq(20.0)
    expect(boosts.fetch("wind_reduc").total).to eq(10.0)
    expect(boosts).not_to have_key("elem_reduc")
    expect(lines.fetch("water_reduc")).to include(label: "Water Reduc.", value: 20.0)
    expect(lines.fetch("wind_reduc")).to include(label: "Wind Reduc.", value: 10.0)
  end

  it "clamps the whole series at its SL10 maximum" do
    ROSE_WEAPONS.each do |attrs|
      boosts = boosts_for(attrs.fetch(:id), skill_level: 15)
      expected_atk = attrs.fetch(:profile) == :brier ? 12.0 : 15.0

      expect(boosts.fetch("atk").by_series.fetch("ex")).to eq(expected_atk)
    end
  end

  it "records the reduced element and source for every series member" do
    ROSE_WEAPONS.each do |attrs|
      version = Weapon.find_by!(granblue_id: attrs.fetch(:id))
                      .weapon_skills.find_by!(position: 1)
                      .weapon_skill_versions.find_by!(ordinal: 0)
      effect = WeaponSkillEffect.find_by!(weapon_skill_version_id: version.id, boost_type: "elem_reduc")

      expect(effect).to have_attributes(
        condition: { "reduced_element" => attrs.fetch(:reduced_element) },
        provenance: CurateRoseCrystalSeriesValues::PROVENANCE
      )
    end
  end

  it "is idempotent and survives scoped description extraction" do
    CurateRoseCrystalSeriesValues.new.up
    Weapon.joins(:weapon_series).where(weapon_series: { slug: "rose" }).find_each do |weapon|
      Granblue::Extractors::WeaponSkillDescriptionExtractor.run(weapon: weapon)
    end

    version_ids = WeaponSkillVersion.joins(weapon_skill: { weapon: :weapon_series }).where(
      weapon_series: { slug: "rose" }
    ).select(:id)
    data = WeaponSkillDatum.where(weapon_skill_version_id: version_ids,
                                  provenance: CurateRoseCrystalSeriesValues::PROVENANCE)
    effects = WeaponSkillEffect.where(weapon_skill_version_id: version_ids,
                                      provenance: CurateRoseCrystalSeriesValues::PROVENANCE,
                                      boost_type: "elem_reduc")

    expect(data.count).to eq(12)
    expect(data).to all(have_attributes(sl15: nil, manually_edited_at: be_present))
    expect(effects.count).to eq(8)
    expect(effects).to all(have_attributes(manually_edited_at: be_present))
  end
end
