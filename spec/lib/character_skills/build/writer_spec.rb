# frozen_string_literal: true

require "rails_helper"

RSpec.describe CharacterSkills::Build::Writer do
  samples = {
    vikala: "3040252000", caim: "3040164000", threo: "3040032000", wamdus: "3040419000", orologia: "3040536000"
  }

  def fixture_dir = Rails.root.join("spec/fixtures/character_skills")

  def sample_character(key, granblue_id = self.class.metadata[:samples]&.fetch(key))
    jp = fixture_dir.join("character-#{key}-jpwiki.html")
    create(:character, granblue_id: granblue_id, name_en: key.to_s.capitalize,
                       wiki_raw: fixture_dir.join("character-#{key}-wikidata.txt").read,
                       game_raw_en: JSON.parse(fixture_dir.join("character-#{key}-gamedata.json").read),
                       game_raw_jp: nil, wiki_raw_jp: (jp.read if jp.exist?))
  end

  def graph_for(character)
    Granblue::Parsers::CharacterSkillParser.new(character).graph
  end

  def write(character, graph = graph_for(character))
    described_class.call(character, graph)
  end

  def ids_for(character)
    versions = CharacterSkillVersion.joins(:character_skill).where(character_skills: { character_id: character.id })
    { slots: CharacterSkill.where(character_id: character.id).order(:id).pluck(:id),
      versions: versions.order(:id).pluck(:id),
      effects: SkillEffect.where(character_skill_version_id: versions.select(:id)).order(:id).pluck(:id),
      links: CharacterSkillVersionLink.where(from_version_id: versions.select(:id)).order(:id).pluck(:id) }
  end

  def version(character, kind, position, name)
    # Several versions of a slot can share a name (base and enhanced); take the first.
    CharacterSkillVersion.joins(:character_skill).order(:ordinal)
                         .find_by!(character_skills: { character_id: character.id, kind: kind, position: position }, name_en: name)
  end

  before { Granblue::Parsers::StatusCatalogBuilder.build_all }

  samples.each do |key, granblue_id|
    it "writes #{key} once, then a second write of the same graph changes nothing" do
      character = sample_character(key, granblue_id)
      first = write(character)
      expect(first.slots_created).to be_positive
      expect(first.versions_created).to be_positive
      ids = ids_for(character)

      second = write(character.reload)
      expect(second.to_h.values).to all(eq(0))
      expect(second).not_to be_changed
      expect(ids_for(character)).to eq(ids)
    end
  end

  it "writes what the graph holds: slots, versions, effects and links" do
    character = sample_character(:vikala, samples[:vikala])
    graph = graph_for(character)
    report = write(character, graph)

    versions = graph[:slots].sum { |slot| slot[:versions].size }
    effects = graph[:slots].sum { |slot| slot[:versions].sum { |v| v[:effects].size } }
    expect(report.to_h).to include(slots_created: graph[:slots].size, versions_created: versions,
                                   effects_created: effects, links_created: graph[:links].size)
    expect(CharacterSkill.where(character_id: character.id).pluck(:character_granblue_id).uniq).to eq([samples[:vikala]])
  end

  it "updates a renamed ability in place and keeps its id" do
    character = sample_character(:vikala, samples[:vikala])
    write(character)
    before = version(character, "ability", 2, "Dazzling Dreams")
    ids = ids_for(character)

    graph = graph_for(character)
    renamed = graph[:slots].find { |s| s[:attrs][:kind] == "ability" && s[:attrs][:position] == 2 }[:versions].first
    renamed[:attrs][:name_en] = "Dazzling Dreams Redux"
    report = write(character, graph)

    expect(report.to_h).to include(versions_updated: 1, versions_created: 0, versions_deleted: 0)
    expect(report.to_h.except(:versions_updated).values).to all(eq(0))
    expect(before.reload.name_en).to eq("Dazzling Dreams Redux")
    expect(ids_for(character)).to eq(ids)
  end

  it "deletes a version the build no longer makes, with its effects and links" do
    character = sample_character(:vikala, samples[:vikala])
    write(character)
    alt = version(character, "ability", 2, "Eccentric Parade")
    expect(alt.incoming_links).to exist
    alt_effects = alt.skill_effects.count

    graph = graph_for(character)
    slot = graph[:slots].find { |s| s[:attrs][:kind] == "ability" && s[:attrs][:position] == 2 }
    gone = slot[:versions].find { |v| v[:attrs][:name_en] == "Eccentric Parade" }
    slot[:versions].delete(gone)
    graph[:links].reject! { |l| [l[:from_version_key], l[:to_version_key]].include?(gone[:key]) }
    report = write(character, graph)

    expect(report.to_h).to include(versions_deleted: 1, effects_deleted: alt_effects, links_deleted: 1)
    expect(CharacterSkillVersion.exists?(alt.id)).to be(false)
    expect(SkillEffect.where(character_skill_version_id: alt.id)).to be_empty
  end

  it "keeps link ids across a rebuild" do
    character = sample_character(:caim, samples[:caim])
    write(character)
    links = CharacterSkillVersionLink.joins(from_version: :character_skill)
                                     .where(character_skills: { character_id: character.id })
    expect(links.count).to be_positive
    before = links.order(:id).pluck(:id, :from_version_id, :to_version_id, :relation)

    write(character.reload)
    expect(links.order(:id).pluck(:id, :from_version_id, :to_version_id, :relation)).to eq(before)
  end

  it "clears a column the build no longer produces, and restores defaults" do
    character = sample_character(:orologia, samples[:orologia])
    write(character)
    stored = CharacterSkillVersion.joins(:character_skill).where(character_skills: { character_id: character.id }).first
    stored.update_columns(name_jp: "手で書いた", enhance_levels: [99], trigger_type: "contextual")

    report = write(character.reload)
    stored.reload
    expect(report.versions_updated).to eq(1)
    expect([stored.name_jp, stored.enhance_levels, stored.trigger_type]).not_to include("手で書いた", [99], "contextual")
  end

  it "removes duplicate ordinals left by older builds, keeping the oldest row" do
    character = sample_character(:wamdus, samples[:wamdus])
    write(character)
    original = CharacterSkillVersion.joins(:character_skill).where(character_skills: { character_id: character.id })
                                    .order(:created_at).first
    copy = original.dup.tap { |v| v.created_at = original.created_at + 1.second }
    copy.save!
    SkillEffect.create!(character_skill_version: copy, ordinal: 1, effect_type: "other")

    report = write(character.reload)
    expect(report.to_h).to include(versions_deleted: 1, effects_deleted: 1)
    expect(CharacterSkillVersion.exists?(original.id)).to be(true)
    expect(CharacterSkillVersion.exists?(copy.id)).to be(false)
  end

  it "deletes slots the build no longer makes" do
    character = sample_character(:vikala, samples[:vikala])
    write(character)
    graph = graph_for(character)
    graph[:slots].reject! { |s| s[:attrs][:kind] == "support" }
    report = write(character, graph)

    expect(report.slots_deleted).to eq(2)
    expect(CharacterSkill.where(character_id: character.id, kind: "support")).to be_empty
  end

  it "writes a style row's skills without touching its base's" do
    base = sample_character(:vikala, samples[:vikala])
    write(base)
    ids = ids_for(base)
    style = create(:character, granblue_id: base.granblue_id, style_swap: true, name_en: "Vikala",
                               wiki_raw: base.wiki_raw, game_raw_en: nil)

    write(style)
    expect(ids_for(base)).to eq(ids)
    expect(CharacterSkill.where(character_id: style.id).count).to eq(ids[:slots].size)
  end

  it "collects the icon stems it created or changed" do
    character = sample_character(:vikala, samples[:vikala])
    writer = described_class.new(character, graph_for(character))
    writer.call
    expect(writer.icon_stems).not_to be_empty
    expect(writer.icon_stems).to all(match(/\A\d+_\d+\z/))

    again = described_class.new(character, graph_for(character.reload))
    again.call
    expect(again.icon_stems).to be_empty
  end
end
