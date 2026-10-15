# frozen_string_literal: true

require "rails_helper"

RSpec.describe Granblue::WikiTitle do
  it "decodes, trims and uses spaces" do
    expect(described_class.normalize("Devil%27s_Finger")).to eq("Devil's Finger")
    expect(described_class.normalize("Cla%C3%ADomh Solais")).to eq("Claíomh Solais")
    expect(described_class.normalize("Coco_%26_Mimi")).to eq("Coco & Mimi")
    expect(described_class.normalize("\nKlesha-Cleansing Dharmachakra ")).to eq("Klesha-Cleansing Dharmachakra")
  end

  it "leaves canonical titles, templates and a bare percent sign alone" do
    expect(described_class.normalize("Template:Weapon Skills/Might")).to eq("Template:Weapon Skills/Might")
    expect(described_class.normalize("100% Pure")).to eq("100% Pure")
  end

  it "keeps nil as nil and blank as blank (characters.wiki_en is NOT NULL)" do
    expect(described_class.normalize(nil)).to be_nil
    expect(described_class.normalize("  ")).to eq("")
  end

  it "is what Weapon, Summon and Character store" do
    expect(create(:weapon, wiki_en: "Devil%27s_Finger").wiki_en).to eq("Devil's Finger")
    expect(Summon.new(wiki_en: "Agni_%28Summon%29").wiki_en).to eq("Agni (Summon)")
    expect(Character.new(wiki_en: "Cat%27s_Purr").wiki_en).to eq("Cat's Purr")
  end
end
