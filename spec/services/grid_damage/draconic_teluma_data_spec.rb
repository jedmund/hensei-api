# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Draconic Teluma effect data" do
  REDUCTIONS = { # rubocop:disable Lint/ConstantDefinitionInBlock
    "teluma-inferno" => "fire",
    "teluma-abyss" => "water",
    "teluma-crag" => "earth",
    "teluma-tempest" => "wind",
    "teluma-aureole" => "light",
    "teluma-malice" => "dark"
  }.freeze

  let(:effects) do
    payload = JSON.parse(File.read(Rails.root.join("data", "weapon_skill_effects.json")))
    payload.fetch("effects")
  end

  def key_rows(slug)
    effects.select { |row| row["key_slug"] == slug }
  end

  it "contains the complete passive Teluma inventory" do
    expected = %w[
      teluma-abyss teluma-aureole teluma-crag teluma-endurance teluma-inferno
      teluma-malice teluma-oblivion teluma-omega teluma-optimus teluma-salvation teluma-tempest
    ]

    expect(effects.filter_map { |row| row["key_slug"] if row["key_slug"]&.start_with?("teluma-") }.uniq)
      .to contain_exactly(*expected)
    expect(expected.sum { |slug| key_rows(slug).size }).to eq(13)
  end

  it "models all six elemental reductions with SL15 and SL20 values" do
    REDUCTIONS.each do |slug, element|
      row = key_rows(slug).sole
      aggregate_failures(slug) do
        expect(row).to include("boost_type" => "elem_reduc", "scaling_kind" => "weapon_skill_curve")
        expect(row.dig("condition", "reduced_element")).to eq(element)
        expect(row.dig("condition", "curve"))
          .to eq("formula_type" => "flat", "sl15" => 25.0, "sl20" => 30.0)
      end
    end
  end

  it "models Endurance, Salvation, and Oblivion" do
    expect(key_rows("teluma-endurance").sole.dig("condition", "curve"))
      .to eq("modifier" => "True Dragon Barrier", "series" => "normal")
    expect(key_rows("teluma-salvation").sole)
      .to include("boost_type" => "hp_fixed", "scaling_kind" => "static", "value" => 10_000.0)
    expect(key_rows("teluma-oblivion").sole)
      .to include("boost_type" => "plain_amp", "scaling_kind" => "static", "value" => 10.0)
  end

  it "models Optimus and Omega as Big Majesty in their selected aura frame" do
    { "teluma-optimus" => "normal", "teluma-omega" => "omega" }.each do |slug, series|
      rows = key_rows(slug)
      aggregate_failures(slug) do
        expect(rows.map { |row| row["boost_type"] }).to contain_exactly("atk", "hp")
        expect(rows).to all(include("scaling_kind" => "weapon_skill_curve", "frame_rule" => "teluma"))
        expect(rows).to all(satisfy do |row|
          row.dig("condition", "curve") == { "modifier" => "Majesty", "series" => series, "size" => "big" }
        end)
      end
    end
  end

  it "migrates idempotently, preserves provenance, and installs exact key compatibility" do
    WeaponSkillEffect.where(key_slug: CompleteDraconicTelumaEffects::KEYS.keys).delete_all
    WeaponSkillEffect.create!(
      key_slug: "teluma-inferno", modifier: "Inferno Teluma", boost_type: "elem_reduc",
      series: "ex", scaling_kind: "static", value: 25, value_unit: "percent",
      stacking: "additive", applies_to: "all_allies", provenance: "test_curation"
    )

    2.times { CompleteDraconicTelumaEffects.new.up }

    replacement = WeaponSkillEffect.find_by!(key_slug: "teluma-inferno", boost_type: "elem_reduc")
    expect(WeaponSkillEffect.where(key_slug: CompleteDraconicTelumaEffects::KEYS.keys).count).to eq(13)
    expect(replacement).to have_attributes(
      scaling_kind: "weapon_skill_curve", manually_edited_at: nil, provenance: "test_curation"
    )
    expect(WeaponKey.find_by!(slug: "teluma-salvation").weapon_series.pluck(:slug))
      .to contain_exactly("draconic-providence")
    expect(WeaponKey.find_by!(slug: "teluma-inferno").weapon_series.pluck(:slug))
      .to contain_exactly("draconic", "draconic-providence")
  end

  it "retains curation metadata on the known manual Oblivion anchor" do
    scope = WeaponSkillEffect.where(key_slug: CompleteDraconicTelumaEffects::KEYS.keys)
    scope.delete_all
    edited_at = 1.day.ago
    WeaponSkillEffect.create!(
      key_slug: "teluma-oblivion", modifier: "Oblivion Teluma", boost_type: "plain_amp",
      series: "ex", scaling_kind: "static", value: 10, value_unit: "percent",
      stacking: "additive", applies_to: "element_allies", manually_edited_at: edited_at,
      provenance: "manual"
    )

    2.times { CompleteDraconicTelumaEffects.new.up }

    replacement = WeaponSkillEffect.find_by!(key_slug: "teluma-oblivion", boost_type: "plain_amp")
    expect(replacement).to have_attributes(
      value: 10, manually_edited_at: be_within(1.second).of(edited_at), provenance: "manual"
    )
  end

  it "refuses to replace a targeted manually edited row" do
    scope = WeaponSkillEffect.where(key_slug: CompleteDraconicTelumaEffects::KEYS.keys)
    scope.delete_all
    effect = WeaponSkillEffect.create!(
      key_slug: "teluma-inferno", modifier: "Inferno Teluma", boost_type: "elem_reduc",
      series: "ex", scaling_kind: "static", value: 17, value_unit: "percent",
      stacking: "additive", applies_to: "all_allies", manually_edited_at: 1.day.ago,
      provenance: "manual_test"
    )

    expect { CompleteDraconicTelumaEffects.new.up }
      .to raise_error(RuntimeError, /Manual Draconic effects require review/)
    expect(effect.reload).to have_attributes(
      scaling_kind: "static", value: 17, provenance: "manual_test"
    )
    expect(scope.count).to eq(1)
  end
end
