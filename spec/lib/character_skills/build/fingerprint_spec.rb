# frozen_string_literal: true

require "rails_helper"

RSpec.describe CharacterSkills::Build::Fingerprint do
  let(:icons) { Pathname.new(Dir.mktmpdir).join("icons.json") }
  let(:character) do
    create(:character, granblue_id: "3040999000", element: 2,
                       wiki_raw: "{{Character|a1_name=Fire}}", wiki_raw_jp: "<p>アビリティ「炎」</p>",
                       game_raw_en: { "ability" => { "1" => { "name" => "Fire", "class_name" => "1_1" } } },
                       game_raw_jp: nil)
  end

  def fingerprint(record = character.reload) = described_class.new(icon_snapshot_path: icons).for(record)
  def fingerprints(relation = Character.where(id: character.id)) = described_class.new(icon_snapshot_path: icons).for_relation(relation)

  after { FileUtils.rm_rf(icons.dirname) }

  it "is the same from the SQL path and the in-memory path, non-ASCII text included" do
    expect(fingerprints).to eq(character.id => fingerprint)
  end

  it "tells nil from an empty string on both paths" do
    character.update_columns(wiki_raw_jp: nil)
    nil_fp = fingerprint
    character.update_columns(wiki_raw_jp: "")
    expect(fingerprint).not_to eq(nil_fp)
    expect(fingerprints[character.id]).to eq(fingerprint)
  end

  it "doesn't depend on jsonb key order" do
    reordered = character.reload.dup.tap { |c| c.game_raw_en = { "ability" => { "1" => { "class_name" => "1_1", "name" => "Fire" } } } }
    expect(fingerprint(reordered)).to eq(fingerprint)
  end

  it "doesn't change with fetch times or unrelated columns" do
    before = fingerprint
    character.update_columns(wiki_raw_fetched_at: Time.current, wiki_raw_jp_fetched_at: Time.current, name_en: "Renamed")
    expect(fingerprint).to eq(before)
  end

  it "doesn't depend on row order in the statuses catalogue" do
    Status.create!(name_en: "Zeta", category: "buff")
    Status.create!(name_en: "Alpha", category: "buff")
    expect(fingerprints(Character.where(id: character.id).order(:name_en))).to eq(character.id => fingerprint)
  end

  {
    "wiki_raw" => "{{Character|a1_name=Ice}}",
    "wiki_raw_jp" => "<p>氷</p>",
    "game_raw_en" => { "ability" => {} },
    "game_raw_jp" => { "ability" => {} },
    "element" => 3,
    "granblue_id" => "3040999001",
    "style_swap" => true
  }.each do |column, value|
    it "changes when #{column} changes" do
      before = fingerprint
      character.update_columns(column => value)
      expect(fingerprint).not_to eq(before)
    end
  end

  it "changes when a status's category changes" do
    status = Status.create!(name_en: "Charge Boost", category: "debuff")
    before = fingerprint
    status.update!(category: "buff")
    expect(fingerprint).not_to eq(before)
  end

  it "changes when a status is added or renamed" do
    before = fingerprint
    status = Status.create!(name_en: "Burning", category: "debuff")
    added = fingerprint
    status.update!(name_en: "Burned")
    expect([before, added, fingerprint].uniq.size).to eq(3)
  end

  it "changes when the icon snapshot appears or changes" do
    absent = fingerprint
    icons.write("[]\n")
    present = fingerprint
    icons.write("[{\"granblue_id\":\"3040999000\"}]\n")
    expect([absent, present, fingerprint].uniq.size).to eq(3)
  end

  it "changes when Build::VERSION is bumped" do
    before = fingerprint
    stub_const("CharacterSkills::Build::VERSION", CharacterSkills::Build::VERSION + 1)
    expect(fingerprint).not_to eq(before)
  end
end
