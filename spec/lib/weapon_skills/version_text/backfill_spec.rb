# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::VersionText::Backfill do
  let(:store) { WeaponSkills::SourceStore::Memory.new }

  def expanded_table(rows)
    cells = rows.map { |name, desc| %(<td class="skill-name">#{name}</td><td class="skill-desc">#{desc}</td>) }
    %(<div class="weapon-skills">\n#{cells.join("\n")}\n</div>)
  end

  def version_on(weapon, position:, ordinal:, name:, skill_text: nil)
    slot = WeaponSkill.find_or_create_by!(weapon_granblue_id: weapon.granblue_id, position: position)
    skill = Skill.find_or_create_by!(name_en: name, skill_type: :weapon)
    skill.update!(description_en: skill_text) if skill_text
    create(:weapon_skill_version, weapon_skill: slot, skill: skill, ordinal: ordinal)
  end

  context "with a Celestial (series-template) weapon" do
    let(:weapon) { create(:weapon, name_en: "Altruism-Soul Staff", wiki_en: "Altruism-Soul Staff") }
    # The shared skill row carries tier II's text: the leak this column fixes.
    let(:leaked) { "Boost to ATK. (Boost to elemental ATK and specs for staff-specialty allies.)" }
    let!(:tier1) { version_on(weapon, position: 1, ordinal: 0, name: "Ultimate Wisdom's Shine", skill_text: leaked) }
    let!(:tier2) { version_on(weapon, position: 4, ordinal: 0, name: "Ultimate Wisdom's Shine II", skill_text: leaked) }

    before do
      raw = "{{Weapon/Common/Celestial\n|name=Altruism-Soul Staff\n|s2_name=Ultimate Wisdom's Shine\n" \
            "|jps2_desc=攻撃力上昇\n}}"
      store.put("wiki_raw", "Altruism-Soul Staff", raw, page_kind: "series_template")
      store.put("transclusion", "Template:Weapon/Common/Celestial", "{{Weapon\n|s1_name={{{s1_name|}}}\n}}")
      table = expanded_table(
        "Ultimate Wisdom's Shine" => "Boost to ATK. ([[API#X|Boost to specs for staff-specialty allies.]])",
        "Ultimate Wisdom's Shine II" => "Boost to ATK. ([[API#X|Boost to elemental ATK and specs for staff allies.]])"
      )
      store.put("expanded", "Altruism-Soul Staff", table, page_kind: "series_template")
    end

    it "gives tier I and tier II their own texts, with no E. ATK on tier I" do
      result = described_class.run(store: store)

      text1 = WeaponSkills::VersionText.for(tier1.reload, :en)
      text2 = WeaponSkills::VersionText.for(tier2.reload, :en)
      expect(text1).not_to eq(text2)
      expect(text1).not_to match(/elemental ATK/i)
      expect(text2).to match(/elemental ATK/i)
      expect(WeaponSkills::VersionText.for(tier1, :jp)).to eq("攻撃力上昇")
      expect(result.en_sources).to eq(expanded: 2)
      expect(result.fallbacks).to be_empty
    end
  end

  context "with an inline page" do
    let(:weapon) { create(:weapon, name_en: "Lovers-Death", wiki_en: "Lovers-Death") }
    let!(:base) { version_on(weapon, position: 0, ordinal: 0, name: "Demise", skill_text: "Tier one text") }
    let!(:upgraded) { version_on(weapon, position: 0, ordinal: 1, name: "Demise") }
    let!(:orphan) { version_on(weapon, position: 1, ordinal: 0, name: "Migrated Skill", skill_text: "Curated text") }

    before do
      raw = "{{Weapon\n|name=Lovers-Death\n|s1_name=Demise\n|ens1_desc=Tier one text\n|s1_desc=Long tier one\n" \
            "|jps1_desc=一段階目\n|s1_lvl=1\n|s1_4s_name=Demise\n|s1_4s_desc=Tier two text\n|s1_4s_lvl=150\n}}"
      store.put("wiki_raw", "Lovers-Death", raw, page_kind: "inline")
    end

    it "keeps two tiers that share a name apart" do
      described_class.run(store: store)

      expect(base.reload.read_attribute(:description_en)).to eq("Tier one text")
      expect(base.read_attribute(:description_jp)).to eq("一段階目")
      expect(upgraded.reload.read_attribute(:description_en)).to eq("Tier two text")
    end

    it "copies the skill's text where the page has none, and reports it" do
      result = described_class.run(store: store)

      expect(orphan.reload.read_attribute(:description_en)).to eq("Curated text")
      expect(result.en_sources).to eq(tier: 2, fallback: 1)
      expect(result.fallbacks).to contain_exactly(
        a_hash_including(weapon_granblue_id: weapon.granblue_id, position: 1, skill: "Migrated Skill")
      )
    end

    it "leaves filled versions alone unless forced, and writes nothing on a dry run" do
      base.update_columns(description_en: "Overlay text")

      described_class.run(store: store, dry_run: true)
      expect(upgraded.reload.read_attribute(:description_en)).to be_nil

      described_class.run(store: store)
      expect(base.reload.read_attribute(:description_en)).to eq("Overlay text")

      described_class.run(store: store, force: true)
      expect(base.reload.read_attribute(:description_en)).to eq("Tier one text")
    end

    it "is not changed by a later write to the shared skill" do
      described_class.run(store: store)
      base.skill.update!(description_en: "Another weapon's reparse")

      expect(WeaponSkills::VersionText.for(base.reload, :en)).to eq("Tier one text")
    end
  end

  it "falls back for a weapon with no stored page" do
    weapon = create(:weapon, wiki_en: "Nowhere")
    version = version_on(weapon, position: 0, ordinal: 0, name: "Lonely", skill_text: "Skill text")

    result = described_class.run(store: store)

    expect(version.reload.read_attribute(:description_en)).to eq("Skill text")
    expect(result.fallbacks.first[:page_kind]).to eq("none")
  end
end
