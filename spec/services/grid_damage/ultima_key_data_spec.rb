# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ultima key effect data" do
  let(:effects) do
    payload = JSON.parse(File.read(Rails.root.join("data", "weapon_skill_effects.json")))
    payload.fetch("effects")
  end

  def key_rows(slug)
    effects.select { |row| row["key_slug"] == slug }
  end

  it "models Rubell ATK and HP at each documented skill-level anchor" do
    rows = effects.select { |row| row["key_slug"].nil? && row["modifier"] == "Rubell" }
    expect(rows.map { |row| row["boost_type"] }).to contain_exactly("atk", "hp")

    expect(rows.index_by { |row| row["boost_type"] }.transform_values { |row| row.dig("condition", "curve") })
      .to eq(
        "atk" => { "formula_type" => "flat", "sl10" => 15.0, "sl15" => 20.0, "sl20" => 25.0 },
        "hp" => { "formula_type" => "flat", "sl10" => 10.0, "sl15" => 15.0, "sl20" => 20.0 }
      )
    expect(rows).to all(include("scaling_kind" => "weapon_skill_curve"))
    expect(rows).to all(satisfy { |row| row.dig("condition", "type") == "weapon_specialty" })
  end

  it "models all six standard Gauph keys and gates them by weapon specialty" do
    expected = {
      "gauph-courage" => %w[critical],
      "gauph-strength" => %w[stamina],
      "gauph-strife" => %w[da ta],
      "gauph-vitality" => %w[hp],
      "gauph-will" => %w[atk],
      "gauph-zeal" => %w[enmity]
    }

    expected.each do |slug, boost_types|
      rows = key_rows(slug)
      aggregate_failures(slug) do
        expect(rows.map { |row| row["boost_type"] }).to contain_exactly(*boost_types)
        expect(rows).to all(satisfy { |row| row.dig("condition", "type") == "weapon_specialty" })
      end
    end
  end

  it "reuses the canonical Stamina and Enmity curves" do
    expect(key_rows("gauph-strength").sole.dig("condition", "curve"))
      .to eq("modifier" => "Stamina", "series" => "normal", "size" => "big_ii")
    expect(key_rows("gauph-zeal").sole.dig("condition", "curve"))
      .to eq("modifier" => "Enmity", "series" => "normal", "size" => "big")
  end

  it "migrates idempotently and preserves provenance" do
    scope = WeaponSkillEffect.where(key_slug: FixUltimaSkillCurves::KEY_SLUGS).or(
      WeaponSkillEffect.where(key_slug: nil, weapon_skill_version_id: nil, modifier: "Rubell")
    )
    scope.delete_all
    WeaponSkillEffect.create!(
      key_slug: "gauph-courage", modifier: "Gauph Key of Courage", boost_type: "critical",
      series: "ex", scaling_kind: "static", value: 20, value_unit: "percent",
      stacking: "additive", applies_to: "all_allies", provenance: "test_curation"
    )

    2.times { FixUltimaSkillCurves.new.up }

    replacement = WeaponSkillEffect.find_by!(key_slug: "gauph-courage", boost_type: "critical")
    expect(scope.count).to eq(9)
    expect(replacement).to have_attributes(
      scaling_kind: "weapon_skill_curve", manually_edited_at: nil, provenance: "test_curation"
    )
  end

  it "upgrades the known manual SL20 anchors and retains their curation metadata" do
    scope = WeaponSkillEffect.where(key_slug: FixUltimaSkillCurves::KEY_SLUGS).or(
      WeaponSkillEffect.where(key_slug: nil, weapon_skill_version_id: nil, modifier: "Rubell")
    )
    scope.delete_all
    edited_at = 1.day.ago
    WeaponSkillEffect.create!(
      key_slug: "gauph-courage", modifier: "Gauph Key of Courage", boost_type: "critical",
      scaling_kind: "static", value: 20, value_unit: "percent", stacking: "additive",
      applies_to: "element_allies", manually_edited_at: edited_at, provenance: "golden:test"
    )

    2.times { FixUltimaSkillCurves.new.up }

    replacement = WeaponSkillEffect.find_by!(key_slug: "gauph-courage", boost_type: "critical")
    expect(replacement).to have_attributes(
      scaling_kind: "weapon_skill_curve", manually_edited_at: be_within(1.second).of(edited_at),
      provenance: "golden:test"
    )
  end

  it "refuses to replace a targeted manually edited row" do
    scope = WeaponSkillEffect.where(key_slug: FixUltimaSkillCurves::KEY_SLUGS).or(
      WeaponSkillEffect.where(key_slug: nil, weapon_skill_version_id: nil, modifier: "Rubell")
    )
    scope.delete_all
    effect = WeaponSkillEffect.create!(
      key_slug: "gauph-courage", modifier: "Gauph Key of Courage", boost_type: "critical",
      series: "ex", scaling_kind: "static", value: 17, value_unit: "percent",
      stacking: "additive", applies_to: "all_allies", manually_edited_at: 1.day.ago,
      provenance: "manual_test"
    )

    expect { FixUltimaSkillCurves.new.up }
      .to raise_error(RuntimeError, /Manual Ultima effects require review/)
    expect(effect.reload).to have_attributes(
      scaling_kind: "static", value: 17, provenance: "manual_test"
    )
    expect(scope.count).to eq(1)
  end
end
