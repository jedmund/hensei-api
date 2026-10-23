# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::SummonBlueprint do
  it "includes a trimmed series in the list view so reps can pick ULB art" do
    summon = create(:summon, summon_series: create(:summon_series, :odious))

    series = described_class.render_as_hash(summon, view: :list)[:series]

    expect(series).to eq(id: summon.summon_series_id, slug: "odious")
  end

  it "sends a nil series in the list view for summons without one" do
    summon = create(:summon)

    expect(described_class.render_as_hash(summon, view: :list)[:series]).to be_nil
  end
end
