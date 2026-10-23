# frozen_string_literal: true

require "rails_helper"

RSpec.describe CharacterSkills::Build::Runner do
  include ActiveJob::TestHelper

  let(:io) { StringIO.new }

  def wiki(name = "Fire", passive: "Boost.")
    <<~WIKI
      {{Character
      |abilitycount=1
      |a1_name=#{name}
      |a1_effdesc=Inflict {{status|Burned|a=5}}.
      |a1_cd=7
      |a1_icon=Ability_m_100_1.png
      |s_abilitycount=1
      |sa_name=Passive
      |sa_desc=#{passive}
      }}
    WIKI
  end

  def make(granblue_id, **attrs)
    Character.without_skill_build do
      create(:character, granblue_id: granblue_id, element: 2, wiki_raw: wiki, **attrs)
    end
  end

  def run(mode: "write", **)
    described_class.new(mode: mode, io: io, **).call
  end

  def skill_ids(character)
    CharacterSkillVersion.joins(:character_skill).where(character_skills: { character_id: character.id }).order(:id).pluck(:id)
  end

  let!(:first) { make("3040900001") }
  let!(:second) { make("3040900002") }

  describe "instant statuses that last (D56)" do
    it "lists the mentions it counted as buffs or debuffs after the summary, for review" do
      Granblue::Parsers::StatusList.use(<<~LUA)
        local effects = { ['Bomb'] = { status = '7097', detail = "All foes take DMG at end of turn (Can't be removed)" } }
        return { buffs = {}, debuffs = {}, effects = effects, aliases = {} }
      LUA
      raw = wiki.sub("|a1_effdesc=Inflict {{status|Burned|a=5}}.", "|a1_effdesc={{InfoDes|num=0|des=Inflict {{status|Bomb}} on all foes.}}")
      Character.without_skill_build { first.update!(wiki_raw: raw) }
      summary = run(ids: %w[3040900001])
      expect(summary.counted_instants).to contain_exactly(
        include(status: "Bomb", reason: "description: end of turn", raw: "{{status|Bomb}}")
      )
      expect(io.string).to include("1 instant status mentions counted as buffs or debuffs (D56), for review:")
      expect(io.string).to include("3040900001 #{first.name_en}: Bomb (description: end of turn) {{status|Bomb}}")
      effect = SkillEffect.joins(character_skill_version: :character_skill)
                          .find_by(character_skills: { character_id: first.id }, ordinal: 1)
      expect(effect.category).to eq("debuff")
    end
  end

  describe "scope" do
    it "covers characters with wiki_raw or skills, and leaves the rest out" do
      make("3040900003", wiki_raw: nil)
      summary = run
      expect(summary.in_scope).to eq(2)
      expect(summary.built).to eq(2)
    end

    it "narrows to ids, both styles of a granblue_id, and names unknown ids" do
      style = make("3040900001", style_swap: true, wiki_raw: wiki("Super Fire"))
      summary = run(ids: %w[3040900001 3040999999])
      expect(summary.results.map(&:character)).to contain_exactly(first, style)
      expect(io.string).to include("Not in scope (no wiki_raw or skills): 3040999999")
      expect(version_names(style)).to include("Super Fire")
      expect(version_names(first)).to include("Fire")
    end
  end

  def version_names(character)
    CharacterSkillVersion.joins(:character_skill).where(character_skills: { character_id: character.id }).pluck(:name_en)
  end

  describe "write" do
    it "stores the fingerprint and skips the character until an input changes" do
      run
      expect(first.reload.character_skill_build_fingerprint).to match(/\A\h{64}\z/)
      expect(run.stale).to eq(0)

      put_source(first, :wiki_raw, wiki("Blaze"))
      summary = run
      expect(summary.stale).to eq(1)
      expect(summary.results.map(&:character)).to eq([first])
      expect(version_names(first)).to include("Blaze")
    end

    it "builds every character in scope with all: true, and a rebuild changes nothing" do
      run
      ids = skill_ids(first)
      summary = run(all: true)
      expect(summary.built).to eq(2)
      expect(summary.counts).not_to be_changed
      expect(summary.differing).to eq(0)
      expect(skill_ids(first)).to eq(ids)
    end

    it "makes every character stale when Build::VERSION is bumped" do
      run
      stub_const("CharacterSkills::Build::VERSION", CharacterSkills::Build::VERSION + 1)
      expect(run.stale).to eq(2)
    end

    it "refreshes the status catalogue from the stored sources first" do
      expect { run }.to change { Status.where(name_en: "Burned").count }.from(0).to(1)
    end

    it "refreshes the catalogue from given records only, when given records" do
      allow(Granblue::Parsers::StatusCatalogBuilder).to receive(:build_for).and_call_original
      run(characters: [first])
      expect(Granblue::Parsers::StatusCatalogBuilder).to have_received(:build_for).with([first])
    end

    it "keeps a failing character's rows, counts it, leaves it stale and carries on" do
      run
      ids = skill_ids(first)
      put_source(first, :wiki_raw, wiki("Blaze"))
      put_source(second, :wiki_raw, wiki("Frost"))
      allow(CharacterSkills::Build::Writer).to receive(:new).and_call_original
      allow(CharacterSkills::Build::Writer).to receive(:new).with(having_attributes(id: first.id), anything)
                                                            .and_raise(ActiveRecord::RecordInvalid)

      summary = run
      expect(summary.failed).to eq(1)
      expect(summary.errors.map(&:first)).to eq([first.granblue_id])
      expect(skill_ids(first)).to eq(ids)
      expect(version_names(second)).to include("Frost")
      expect(run(mode: "shadow").stale).to eq(1)
    end

    it "queues one icon download for the stems it created, and none when nothing changed" do
      expect { run }.to have_enqueued_job(CharacterSkills::IconDownloadJob).with(["100_1"]).exactly(:once)
      expect { run(all: true) }.not_to have_enqueued_job(CharacterSkills::IconDownloadJob)
    end
  end

  describe "missing sources" do
    it "doesn't rebuild a character with skills and a blank wiki_raw" do
      run
      ids = skill_ids(first)
      put_source(first, :wiki_raw, "")
      summary = run(all: true)
      expect(summary.no_source).to eq(1)
      expect(skill_ids(first)).to eq(ids)
      expect(io.string).to include("no wiki_raw; kept its existing skills")
    end

    it "doesn't let an empty build delete a character's skills" do
      run
      ids = skill_ids(first)
      stored = first.reload.character_skill_build_fingerprint
      put_source(first, :wiki_raw, "#REDIRECT [[Somewhere]]")
      summary = run
      expect(summary.empty).to eq(1)
      expect(summary).to be_drift
      expect(skill_ids(first)).to eq(ids)
      expect(first.reload.character_skill_build_fingerprint).to eq(stored)
    end
  end

  describe "shadow" do
    it "writes nothing and reports what would change, per character" do
      summary = run(mode: "shadow")
      expect(summary.built).to eq(2)
      expect(CharacterSkill.count).to eq(0)
      expect(first.reload.character_skill_build_fingerprint).to be_nil
      changes = summary.results.find { |r| r.character == first }.changes
      expect(changes.map(&:to_h)).to include(
        { kind: "ability", position: 1, ordinal: 1, name: { en: "Fire", ja: nil }, change: "created", fields: [] }
      )
      expect(io.string).to include("Differences: 4 versions across 2 characters", "== structure (4)")
    end

    it "reports field-level differences grouped by category, and none after a write" do
      run
      put_source(first, :wiki_raw, wiki("Blaze", passive: "Boost more."))
      summary = run(mode: "shadow", diff_limit: 1)
      change = summary.results.first.changes.find { |c| c.kind == "ability" }
      expect(change.to_h).to include(change: "updated", fields: ["name_en"])
      expect(io.string).to include("name ", "description ", "== name (1)", "name_en: \"Fire\" → \"Blaze\"",
                                   "… 1 more differences not shown")
      expect(version_names(first)).to include("Fire")

      run
      expect(run(mode: "shadow", all: true).differing).to eq(0)
    end

    it "doesn't queue icon downloads" do
      expect { run(mode: "shadow") }.not_to have_enqueued_job(CharacterSkills::IconDownloadJob)
    end

    it "builds given records as loaded, unsaved text included" do
      run
      first.wiki_raw = wiki("Unsaved")
      summary = run(mode: "shadow", characters: [first])
      expect(summary.results.first.changes.first.after["name_en"]).to eq("Unsaved")
      expect(version_names(first.reload)).to include("Fire")
    end
  end

  describe "icon_fallbacks" do
    it "lists versions whose icon the builder took from the wiki stem" do
      allow_any_instance_of(Granblue::Parsers::CharacterSkillParser).to receive(:graph).and_wrap_original do |original|
        original.call.tap { |graph| graph[:slots].first[:versions].first[:game_icon_source] = "wiki" }
      end
      summary = run(characters: [first])
      expect(summary.results.first.icon_fallbacks).to eq([{ kind: "ability", position: 1, ordinal: 1, name: { en: "Fire", ja: nil } }])
    end
  end

  describe ".deploy" do
    it "does nothing when off" do
      expect(described_class.deploy(mode: "off", io: io)).to be_nil
      expect(CharacterSkill.count).to eq(0)
    end

    it "never raises in shadow" do
      allow(Granblue::Parsers::StatusCatalogBuilder).to receive(:build_all).and_raise("boom")
      expect(described_class.deploy(mode: "shadow", io: io)).to be_nil
      expect(io.string).to include("build_character_skills (shadow) failed; the deploy continues: RuntimeError: boom")
    end

    it "writes in write mode and reports failures without raising" do
      allow(CharacterSkills::Build::Writer).to receive(:new).and_call_original
      allow(CharacterSkills::Build::Writer).to receive(:new).with(having_attributes(id: first.id), anything).and_raise("boom")
      summary = described_class.deploy(mode: "write", io: io)
      expect(summary.built).to eq(1)
      expect(io.string).to include("1 characters failed and kept their existing rows")
    end
  end
end
