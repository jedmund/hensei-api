# frozen_string_literal: true

require "rails_helper"

# Each example is a form found in the stored gbf.wiki descriptions.
RSpec.describe WeaponSkills::WikiMarkup do
  def segments(text, element: 1, locale: :en) = described_class.segments(text, element: element, locale: locale)

  it "returns plain text unchanged" do
    expect(segments("Big boost to fire allies' ATK")).to eq([{ text: "Big boost to fire allies' ATK" }])
  end

  it "turns {{tt}} into text with a tooltip" do
    expect(segments("Take {{tt|5% damage|Based on max HP.}} every turn")).to eq(
      [{ text: "Take " }, { text: "5% damage", tooltip: "Based on max HP." }, { text: " every turn" }]
    )
  end

  it "keeps a tooltip's line breaks and drops its bold" do
    expect(segments("{{tt|20% boost|'''Size:''' Big<hr />'''Modifier:''' EX}} to ATK")).to eq(
      [{ text: "20% boost", tooltip: "Size: Big\nModifier: EX" }, { text: " to ATK" }]
    )
  end

  it "reads links inside a tooltip's text" do
    expect(segments("{{tt|[[Weapon_Skills|Medium boost]]|Normal}}")).to eq([{ text: "Medium boost", tooltip: "Normal" }])
  end

  it "resolves the weapon's element, including through an empty template parameter" do
    expect(described_class.plain("Small boost to {{WeaponElement|wpn}} allies", element: 1)).to eq("Small boost to Fire allies")
    expect(segments("Big boost to {{WeaponElement|{{{element|}}}}} allies' ATK")).to eq([{ text: "Big boost to Fire allies' ATK" }])
    expect(segments("{{WeaponElement}} allies", locale: :ja)).to eq([{ text: "火 allies" }])
  end

  it "names the element a weapon is strong against" do
    expect(segments("Bonus DMG to {{WeaponWeakElement}} foes")).to eq([{ text: "Bonus DMG to Wind foes" }])
  end

  it "says same-element when the weapon has no element" do
    expect(segments("Boost to {{WeaponElement}} allies", element: 0)).to eq([{ text: "Boost to same-element allies" }])
  end

  it "gives a status its amount, duration and note as a tooltip" do
    expect(segments("{{status|DEF Down|a=20%|c=Can't be removed.|t=1T}}")).to eq(
      [{ text: "DEF Down", tooltip: "20% · 1T\nCan't be removed." }]
    )
    expect(segments("{{Status|C.A. DMG Cap Boosted|a=3%|am=15%|t=i}}")).to eq(
      [{ text: "C.A. DMG Cap Boosted", tooltip: "3% · Max 15% · Indefinite" }]
    )
    expect(segments("{{status|Charged}}")).to eq([{ text: "Charged" }])
  end

  it "shows an {{atkmod}} modifier as a tooltip" do
    expect(segments("{{atkmod|ATK|m=ex}}")).to eq([{ text: "ATK", tooltip: "Modifier: EX" }])
  end

  it "renders other templates as their first argument, positional or named" do
    expect(segments("{{ClassSkill|Limit Burst}} and {{classSkill|skill=Aether Blast III}}")).to eq(
      [{ text: "Limit Burst and Aether Blast III" }]
    )
    expect(segments("a {{Crit|critical hit|100|700}} ({{verify|~3%}})")).to eq([{ text: "a critical hit (~3%)" }])
  end

  it "renders a template parameter's default and nested templates inside it" do
    text = "{{{s2_desc|{{ClassSkill|Retaliation Reprise}} self-inflicts {{status|DEF Down|t=1T}} instead.}}}"
    expect(segments(text)).to eq(
      [{ text: "Retaliation Reprise self-inflicts " }, { text: "DEF Down", tooltip: "1T" }, { text: " instead." }]
    )
  end

  it "marks bold, turns <br> into line breaks and drops refs" do
    text = "'''When main weapon (MC only):'''<br />Boost.<ref name=\"x\">Source, https://x</ref>"
    expect(segments(text)).to eq([{ text: "When main weapon (MC only):", strong: true }, { text: "\nBoost." }])
  end

  it "drops file and category links and decodes entities" do
    expect(segments("A&nbsp;[[File:Icon.png|25px]]B [[Category:X]]&amp; C")).to eq([{ text: "A B & C" }])
  end

  it "ends an unclosed template at the end of the text" do
    expect(segments("Boost {{tt|ATK|Big")).to eq([{ text: "Boost " }, { text: "ATK", tooltip: "Big" }])
  end

  it "returns no segments for blank text" do
    expect(segments(nil)).to eq([])
  end
end
