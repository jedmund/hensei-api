# frozen_string_literal: true

require "rails_helper"

RSpec.describe Granblue::CurationAutoExport do
  let(:path) { Rails.root.join("tmp/curation_auto_export_spec.json") }
  let(:version) { create(:weapon_skill_version) }

  before do
    stub_const("Granblue::CurationSnapshot::PATH", path)
    allow(described_class).to receive(:enabled?).and_return(true)
    described_class::DIRTY.make_false
  end

  after { FileUtils.rm_f(path) }

  def effect(stamp)
    WeaponSkillEffect.create!(weapon_skill_version: version, modifier: "Axe Voltage II", boost_type: "ex_atk_sp",
                              scaling_kind: "per_grid_count", value: 8, condition: {}, manually_edited_at: stamp)
  end

  it "exports after a curated row is saved" do
    effect(Time.current)

    described_class.flush!

    exported = JSON.parse(File.read(path))["effects"]
    expect(exported.map { |row| row["modifier"] }).to eq(["Axe Voltage II"])
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
    Granblue::CurationSnapshot.export(path: path)
    curated.destroy!
    before = File.read(path)

    expect(described_class.flush!).to be(false)
    expect(File.read(path)).to eq(before)
  end

  it "checks drift after bulk rake tasks but not around the curation tasks" do
    expect(described_class.rake_bulk_task?(["data:migrate"])).to be(true)
    expect(described_class.rake_bulk_task?(["granblue:recover_july_reparses"])).to be(true)
    expect(described_class.rake_bulk_task?(["granblue:weapon_skill_curation_drift"])).to be(false)
    expect(described_class.rake_bulk_task?(["assets:precompile"])).to be(false)
  end
end
