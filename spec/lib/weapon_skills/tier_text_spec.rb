# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::TierText do
  let(:hash) do
    {
      "s1_name" => "Demise",
      "s1_desc" => "Full text of tier one, by 10%.",
      "ens1_desc" => "Short tier one.",
      "jps1_desc" => "一段階目",
      "s1_lvl" => "1",
      "s1_4s_name" => "Demise",
      "s1_4s_desc" => "Full text of tier two.",
      "s1_4s_lvl" => "150",
      "s2_name" => "{{WeaponSkillMod|x}} Ultimate Wisdom's Shine",
      "jps2_desc" => "極叡導の煌き"
    }
  end

  describe ".from_wiki_hash" do
    it "prefers the English short text and reads the JP field of the same tier" do
      expect(described_class.from_wiki_hash(hash, 1)).to eq(name: "Demise", en: "Short tier one.", jp: "一段階目")
    end

    it "falls back to sN_desc when there is no ensN_desc" do
      expect(described_class.from_wiki_hash(hash, 1, "4s")).to eq(name: "Demise", en: "Full text of tier two.", jp: nil)
    end

    it "drops text the line parser cut short at a multi-line template" do
      cut = hash.merge("jps1_desc" => "{{", "ens1_desc" => "Boost to {{WeaponElement}} allies' ATK")
      expect(described_class.from_wiki_hash(cut, 1)).to eq(name: "Demise", en: "Boost to {{WeaponElement}} allies' ATK", jp: nil)
    end

    it "cleans the name: comments dropped, Dark Opus #ifeq names resolved to their last branch" do
      opus = { "s1_name" => "{{ #ifeq: {{#var: wpn_opus_version}} | omega | Majesty III | Majesty}}<!-- note -->",
               "s1_desc" => "Big boost" }
      expect(described_class.from_wiki_hash(opus, 1)).to eq(name: "Majesty", en: "Big boost", jp: nil)
      expect(described_class.from_wiki_hash(hash, 2)[:name]).to eq("Ultimate Wisdom's Shine")
    end

    it "returns nil for a tier with no name" do
      expect(described_class.from_wiki_hash(hash, 3)).to be_nil
    end
  end

  describe ".tiers" do
    it "keeps two tiers that share a name apart, in unlock order" do
      tiers = described_class.tiers(hash, 1)

      expect(tiers.map { |t| [t[:ordinal], t[:suffix], t[:en]] })
        .to eq([[0, nil, "Short tier one."], [1, "4s", "Full text of tier two."]])
    end
  end

  describe ".jp_for_name" do
    it "finds the JP text by the cleaned English name in any slot" do
      expect(described_class.jp_for_name(hash, "Ultimate Wisdom's Shine")).to eq("極叡導の煌き")
      expect(described_class.jp_for_name(hash, "Nope")).to be_nil
    end
  end

  describe ".from_expanded" do
    let(:html) do
      <<~HTML
        <div class="weapon-skills">
        <td class="skill-name">Ultimate Wisdom's Shine</td><td class="skill-desc">Boost to <span class="tooltip" >ATK<span class="tooltiptext" style="">'''Multiplier:''' [[Damage_Formula#EX|EX]]</span></span>, multiattack rate. ([[API#X|Boost to specs for staff-specialty allies.]])</td>
        <td class="skill-name">Ultimate Wisdom's Shine II</td><td class="skill-desc">Boost to ATK, multiattack rate. ([[API#X|Boost to elemental ATK and specs for staff-specialty allies.]])</td>
      HTML
    end

    it "keys each row's cleaned text by name" do
      rows = described_class.from_expanded(html)

      expect(rows.keys).to eq(["Ultimate Wisdom's Shine", "Ultimate Wisdom's Shine II"])
      expect(rows["Ultimate Wisdom's Shine"][:en]).not_to match(/Multiplier|elemental ATK/)
      expect(rows["Ultimate Wisdom's Shine II"][:en]).to include("elemental ATK")
      expect(rows["Ultimate Wisdom's Shine"][:key_type]).to be_nil
    end

    it "is empty for a blank page" do
      expect(described_class.from_expanded(nil)).to eq({})
    end
  end
end
