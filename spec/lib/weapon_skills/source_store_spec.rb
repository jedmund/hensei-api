# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::SourceStore::Memory do
  subject(:store) { described_class.new }

  it "returns what was stored, with a content hash" do
    store.put("wiki_raw", "Gateway-Star Sword", "{{Weapon/Common/Celestial}}", page_kind: "series_template")
    source = store.fetch("wiki_raw", "Gateway-Star Sword")

    expect(source.body).to eq("{{Weapon/Common/Celestial}}")
    expect(source.sha256).to eq(Digest::SHA256.hexdigest("{{Weapon/Common/Celestial}}"))
    expect(source.page_kind).to eq("series_template")
  end

  it "raises instead of fetching when a source is missing" do
    expect { store.fetch("expanded", "Nowhere") }.to raise_error(WeaponSkills::SourceStore::SourceMissing, /fetch_weapon_sources/)
    expect(store.exist?("expanded", "Nowhere")).to be(false)
  end

  it "rejects unknown kinds" do
    expect { store.put("html", "x", "y") }.to raise_error(ArgumentError)
  end
end
