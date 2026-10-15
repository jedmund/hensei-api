# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::SourceStore::Database do
  subject(:store) { described_class.new }

  let(:weapon) { create(:weapon) }

  it "returns what was stored, with a content hash" do
    store.put("wiki_raw", "Hrunting", "{{Weapon/Common/Illustrious}}", page_kind: "inline", weapon_id: weapon.id)
    source = store.fetch("wiki_raw", "Hrunting")

    expect(source.body).to eq("{{Weapon/Common/Illustrious}}")
    expect(source.sha256).to eq(Digest::SHA256.hexdigest("{{Weapon/Common/Illustrious}}"))
    expect(source.page_kind).to eq("inline")
    expect(WeaponSource.sole.weapon).to eq(weapon)
  end

  it "raises instead of fetching when a source is missing" do
    expect { store.fetch("expanded", "Nowhere") }.to raise_error(WeaponSkills::SourceStore::SourceMissing)
    expect(store.exist?("expanded", "Nowhere")).to be(false)
  end

  it "updates a page no weapon owns in place" do
    store.put("family_template", "Template:Weapon Skills/Might", "old")
    store.put("family_template", "Template:Weapon Skills/Might", "new")

    expect(WeaponSource.where(kind: "family_template").count).to eq(1)
    expect(store.fetch("family_template", "Template:Weapon Skills/Might").body).to eq("new")
  end

  it "finds a page stored for several weapons, newest first" do
    other = create(:weapon)
    store.put("transclusion", "Lagrange", "older", weapon_id: weapon.id, fetched_at: 2.days.ago)
    store.put("transclusion", "Lagrange", "newer", weapon_id: other.id, fetched_at: 1.day.ago)

    expect(store.fetch("transclusion", "Lagrange").body).to eq("newer")
  end

  it "rejects unknown kinds" do
    expect { store.put("html", "x", "y") }.to raise_error(ArgumentError)
  end

  it "stores and finds keys by their canonical title" do
    store = described_class.new
    store.put("wiki_raw", "Devil%27s_Finger", "page")

    expect(WeaponSource.sole.key).to eq("Devil's Finger")
    expect(store.fetch("wiki_raw", "Devil's Finger").body).to eq("page")
    expect(store.fetch("wiki_raw", "Devil%27s Finger").body).to eq("page")
  end
end
