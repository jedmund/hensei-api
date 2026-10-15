# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WeaponSkills::Build::Structure parts" do
  describe WeaponSkills::Build::Structure::Expanded do
    it "drops status icons and their hidden tooltip text" do
      html = "20% Bonus DMG against foes with <span class=\"image_link\"><span class=\"tooltip\">" \
             "[[File:Status_Burned.png|25px|link=Burned]][[Burned|Burned]]<span class=\"tooltiptext\">HP is lowered" \
             "<br /><span class=\"hr\"></span><strong>Strength</strong>: 5000</span></span></span> upon normal attacks."

      expect(described_class.clean(html)).to eq("20% Bonus DMG against foes with Burned upon normal attacks.")
    end

    {
      "Granted power with an anklet." => "anklet",
      "Granted power with a pendulum." => "pendulum",
      "Granted power with a teluma." => "teluma",
      "Granted power with a chain." => "chain",
      "A symbol of apocalyptic corruption. Empowered by a chosen pendulum." => "pendulum",
      "Empowered by a chosen teluma." => "teluma",
      "A gate to the summits of power locked within ultima weapons." => "gate",
      "Power sealed within Ultima." => "ultima"
    }.each do |phrase, key_type|
      it "recognises the key-slot placeholder #{phrase.inspect}" do
        expect(phrase.match(described_class::KEY_SLOT).captures.compact.first.downcase).to eq(key_type)
      end
    end

    it "flags every row after a key-slot placeholder and keeps the base rows" do
      html = <<~HTML
        <div id="weapon-skills"><table>
        <tr><td class="skill-name">Base Skill</td><td class="skill-desc">Big boost to ATK. Multiplier: EX.</td></tr>
        <tr><td class="skill-name">Guiding Revelation</td><td class="skill-desc">Empowered by a chosen pendulum.</td></tr>
        <tr><td class="skill-name">α Revelation</td><td class="skill-desc">10% boost to normal attack DMG cap</td></tr>
        </table>
      HTML
      rows = described_class.rows(html)

      expect(rows.map { |r| [r[:name], r[:key_type], r[:series]] })
        .to eq([["Base Skill", nil, "ex"], ["α Revelation", "pendulum", nil]])
      expect(rows.first[:description]).to start_with("Big boost to ATK.")
      expect(rows.first[:description]).not_to include("Multiplier")
    end
  end

  describe WeaponSkills::Build::Structure::Wikitext do
    let(:template) do
      <<~WIKI
        {{ #vardefine: epic_release_date | {{{release_date|2017-07-24}}} }}{{Weapon
        |s1_name={{{s1_name|}}}
        |s1_icon=template.png
        |s2_lvl={{ #ifeq: {{ #var: epic_release_date }} | 2019-08-06 | 120 }}
        |s3_lvl={{ #if: {{{5star_date|}}} | 200 }}
        |s4_lvl={{{s4_lvl|230}}}
        |s4_4s_name={{{s4_4s_name|{{{s4_u1_name|}}}}}}
        |s4_4s_lvl=250
        }}
      WIKI
    end

    def merged(page) = described_class.merge_template(described_class.fields(page), template)

    it "keeps today's merge order: a template literal wins over the page" do
      expect(merged("|s1_name=A\n|s1_icon=page.png")).to include("s1_name" => "A", "s1_icon" => "template.png")
    end

    it "applies a level default only when the page has no value" do
      expect(merged("|s4_name=X")["s4_lvl"]).to eq("230")
      expect(merged("|s4_name=X\n|s4_lvl=210")["s4_lvl"]).to eq("210")
    end

    it "moves an aliased u1 tier onto the template's 4s fields" do
      fields = merged("|s4_name=X\n|s4_u1_name=X II")

      expect(fields).to include("s4_4s_name" => "X II", "s4_4s_lvl" => "250")
      expect(fields).not_to have_key("s4_u1_name")
    end

    it "evaluates #ifeq and #if levels from the page's parameters" do
      expect(merged("|release_date=2019-08-06")["s2_lvl"]).to eq("120")
      expect(merged("|5star_date=2026-09-07")["s3_lvl"]).to eq("200")
    end

    it "keeps the literal (read as level 0, as today) when the condition is false" do
      expect(merged("|release_date=2020-01-01")["s2_lvl"]).to start_with("{{ #ifeq")
    end

    it "stops at Gameplay Notes" do
      expect(described_class.fields("|s1_name=A\n== Gameplay Notes ==\n|s2_name=B")).not_to have_key("s2_name")
    end
  end

  describe WeaponSkills::Build::Structure::Evaluator do
    let(:template) do
      "{{\n#vardefine: weapon_skill| {{\n  #switch: {{{weapon|}}}\n  |sabre=Thrust\n  |axe|spear=Blow\n  |Other\n  }}\n}}"
    end

    it "evaluates #switch with fall-through and a default" do
      expect(described_class.variables(template, "weapon" => "sabre")).to eq("weapon_skill" => "Thrust")
      expect(described_class.variables(template, "weapon" => "axe")).to eq("weapon_skill" => "Blow")
      expect(described_class.variables(template, "weapon" => "bow")).to eq("weapon_skill" => "Other")
    end

    it "leaves other template calls in place" do
      expect(described_class.evaluate("{{WeaponElement|{{{element|}}}}}'s Majesty", { "element" => "water" }, {}))
        .to eq("{{WeaponElement|water}}'s Majesty")
    end
  end
end
