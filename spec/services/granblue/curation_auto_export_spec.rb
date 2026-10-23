# frozen_string_literal: true

require "rails_helper"

RSpec.describe Granblue::CurationAutoExport do
  let(:root) { Pathname.new(Dir.mktmpdir("curation_auto_export_spec")) }
  let(:dir) { root.join("weapon_skill_curation") }
  let(:version) { create(:weapon_skill_version) }

  before do
    stub_const("Granblue::CurationSnapshot::DIR", dir)
    stub_const("Granblue::CurationSnapshot::LEGACY_PATH", root.join("weapon_skill_curation.json"))
    allow(described_class).to receive(:enabled?).and_return(true)
    described_class::DIRTY.make_false
  end

  after { FileUtils.rm_rf(root) }

  def exported(section)
    Dir.glob(dir.join("*.json").to_s).flat_map { |file| JSON.parse(File.read(file))[section] }
  end

  def effect(stamp)
    WeaponSkillEffect.create!(weapon_skill_version: version, modifier: "Axe Voltage II", boost_type: "ex_atk_sp",
                              scaling_kind: "per_grid_count", value: 8, condition: {}, manually_edited_at: stamp)
  end

  it "exports after a curated row is saved" do
    effect(Time.current)

    described_class.flush!

    expect(exported("effects").map { |row| row["modifier"] }).to eq(["Axe Voltage II"])
  end

  it "ignores rows nobody curated" do
    effect(nil)

    expect(described_class::DIRTY.true?).to be(false)
  end

  it "marks a version dirty when its overrides change" do
    version.update!(suppressed_boosts: ["dmg_cap"], overrides_edited_at: Time.current)

    expect(described_class::DIRTY.true?).to be(true)
  end

  it "won't overwrite a snapshot holding rows this database lacks" do
    curated = effect(Time.current)
    Granblue::CurationSnapshot.export
    curated.destroy!
    before = exported("effects")

    expect(described_class.flush!).to be(false)
    expect(exported("effects")).to eq(before)
  end

  it "checks drift after bulk rake tasks but not around the curation tasks" do
    expect(described_class.rake_bulk_task?(["data:migrate"])).to be(true)
    expect(described_class.rake_bulk_task?(["granblue:build_weapon_skills"])).to be(true)
    expect(described_class.rake_bulk_task?(["granblue:weapon_skill_curation_drift"])).to be(false)
    expect(described_class.rake_bulk_task?(["assets:precompile"])).to be(false)
  end
end
