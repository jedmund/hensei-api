# frozen_string_literal: true

require "rails_helper"

RSpec.describe CharacterSkills::Build::Fingerprint do
  let(:character) do
    create(:character, granblue_id: "3040999000", element: 1,
                       wiki_raw: "{{Character|a1_name=Fire}}", wiki_raw_jp: "<p>アビリティ「炎」</p>",
                       game_raw_en: { "ability" => { "1" => { "name" => "Fire", "class_name" => "1_1" } } },
                       game_raw_jp: nil)
  end

  def fingerprint(record = character.reload) = described_class.new.for(record)
  def fingerprints(relation = Character.where(id: character.id)) = described_class.new.for_relation(relation)

  it "is the same from the SQL path and the in-memory path, non-ASCII text included" do
    expect(fingerprints).to eq(character.id => fingerprint)
  end

  it "treats a blank source as no source, on both paths" do
    put_source(character, :wiki_raw_jp, nil)
    nil_fp = fingerprint
    put_source(character, :wiki_raw_jp, "")
    expect(fingerprint).to eq(nil_fp)
    expect(fingerprints[character.id]).to eq(fingerprint)
  end

  it "doesn't depend on JSON key order" do
    reordered = Character.find(character.id).tap { |c| c.game_raw_en = { "ability" => { "1" => { "class_name" => "1_1", "name" => "Fire" } } } }
    expect(fingerprint(reordered)).to eq(fingerprint)
  end

  it "hashes staged, unsaved text (a preview) as it would be stored" do
    original = fingerprint
    staged = Character.find(character.id).tap { |c| c.wiki_raw = "{{Character|a1_name=Ice}}" }
    expect(fingerprint(staged)).not_to eq(original)
    expect(Source.read(character, :wiki_raw)).to eq("{{Character|a1_name=Fire}}")

    stored = put_source(Character.find(character.id), :wiki_raw, "{{Character|a1_name=Ice}}")
    expect(fingerprint(staged)).to eq(fingerprint(stored))
  end

  # D35: moving the jsonb columns into sources keeps their digest (canonical JSON).
  it "hashes a game payload as the sha256 of its canonical JSON" do
    payload = { "ability" => { "1" => { "name" => "Fire", "class_name" => "1_1" } } }
    canonical = '{"ability":{"1":{"class_name":"1_1","name":"Fire"}}}'
    expect(character.source_sha256(:game_raw_en)).to eq(Digest::SHA256.hexdigest(canonical))
    expect(Source.read(character, :game_raw_en)).to eq(payload)
  end

  it "doesn't change with fetch times or unrelated columns" do
    before = fingerprint
    Source.owned_by(character).update_all(fetched_at: Time.current)
    character.update_columns(name_en: "Renamed")
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
    "element" => 2,
    "granblue_id" => "3040999001",
    "style_swap" => true
  }.each do |column, value|
    it "changes when #{column} changes" do
      before = fingerprint
      if described_class::SOURCES.include?(column)
        put_source(character, column, value)
      else
        character.update_columns(column => value)
      end
      expect(fingerprint).not_to eq(before)
      expect(fingerprints[character.id]).to eq(fingerprint)
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
    put_icon_snapshot("[]\n")
    present = fingerprint
    put_icon_snapshot("[{\"granblue_id\":\"3040999000\"}]\n")
    expect([absent, present, fingerprint].uniq.size).to eq(3)
  end

  it "changes when Build::VERSION is bumped" do
    before = fingerprint
    stub_const("CharacterSkills::Build::VERSION", CharacterSkills::Build::VERSION + 1)
    expect(fingerprint).not_to eq(before)
  end
end
