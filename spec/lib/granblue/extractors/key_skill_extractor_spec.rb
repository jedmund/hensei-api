# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/granblue/extractors/key_skill_extractor")

RSpec.describe Granblue::Extractors::KeySkillExtractor do
  let(:gate) { { "type" => "boost_level", "gte" => 280 } }

  def key_effect(boost_type, value, **attrs)
    { key_slug: "anklet-oblivion", modifier: "Anklet of Oblivion", boost_type: boost_type, series: "ex",
      value: value, scaling_kind: "conditional_flat", value_unit: "percent", condition: gate,
      applies_to: "element_allies", stacking: "additive" }.merge(attrs)
  end

  describe ".run" do
    it "reads series pages from the source store and never the live wiki" do
      expect(Granblue::Parsers::Wiki).not_to receive(:new)
      store = WeaponSkills::SourceStore::Memory.new
      store.put("wiki_raw", "Destroyer Weapons", "no key tables here")

      stats, preview = described_class.run(store: store, dry_run: true)

      expect(stats[:fetch_failed]).to eq(described_class::SERIES_PAGES.size - 1)
      expect(preview).to eq([])
    end

    it "requires a store" do
      expect { described_class.run(dry_run: true) }.to raise_error(ArgumentError, /store/)
    end
  end

  describe ".persist" do
    it "does not replace effects for curated key families" do
      stats = Hash.new(0)

      expect(WeaponSkillEffect).not_to receive(:for_key)
      expect(WeaponSkillEffect).not_to receive(:create!)

      %w[chain-forbiddance pendulum-strength gauph-strength teluma-inferno].each do |slug|
        described_class.send(:persist, slug, [{ value: 10 }], stats)
      end

      expect(stats[:curated_skipped]).to eq(4)
    end

    it "replaces extracted rows but keeps rows a curator edited" do
      WeaponSkillEffect.create!(key_effect("elem_amplify", 20))
      curated = WeaponSkillEffect.create!(key_effect("na_dmg_cap", 10, total_cap: 10, shared_cap_group: "key_na_cap",
                                                                         manually_edited_at: Time.current))
      stats = Hash.new(0)

      described_class.send(:persist, "anklet-oblivion",
                           [key_effect("elem_amplify", 30), key_effect("na_dmg_cap", 12)], stats)

      rows = WeaponSkillEffect.for_key("anklet-oblivion").order(:boost_type)
      expect(rows.map { |e| [e.boost_type, e.value.to_f] }).to eq([["elem_amplify", 30.0], ["na_dmg_cap", 10.0]])
      expect(rows.last).to eq(curated)
      expect(rows.last.shared_cap_group).to eq("key_na_cap")
      expect(stats).to include(keys: 1, effects: 1, preserved: 1)
    end

    it "matches a kept row's condition regardless of key order" do
      WeaponSkillEffect.create!(key_effect("na_dmg_cap", 10, condition: { "gte" => 280, "type" => "boost_level" },
                                                             manually_edited_at: Time.current))
      stats = Hash.new(0)

      expect do
        described_class.send(:persist, "anklet-oblivion", [key_effect("na_dmg_cap", 12)], stats)
      end.not_to raise_error
      expect(stats[:preserved]).to eq(1)
    end

    it "does not touch other keys" do
      other = WeaponSkillEffect.create!(key_effect("elem_amplify", 30, key_slug: "anklet-maximality",
                                                                       modifier: "Anklet of Maximality"))

      described_class.send(:persist, "anklet-oblivion", [key_effect("elem_amplify", 30)], Hash.new(0))

      expect(WeaponSkillEffect.exists?(other.id)).to be(true)
    end
  end
end
