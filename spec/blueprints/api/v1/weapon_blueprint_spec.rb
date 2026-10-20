# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::WeaponBlueprint do
  it "includes the series in the list view so reps can pick transcendence art" do
    weapon = create(:weapon, :opus)

    series = described_class.render_as_hash(weapon, view: :list)[:series]

    expect(series).to include(id: weapon.weapon_series_id, slug: "dark-opus")
  end
end
