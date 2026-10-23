# frozen_string_literal: true

require "rails_helper"

# Each example is a form found in the stored gbf.wiki character pages.
RSpec.describe CharacterSkills::DescriptionMarkup do
  def segments(text, effects: [], skill_name: nil) = described_class.segments(text, effects: effects, skill_name: skill_name)

  def status_effect(ordinal, raw) = { ordinal: ordinal, raw: raw }

  it "points each status mention at the effect parsed from it" do
    effects = [status_effect(1, "{{status|Death Sentence (Sariel) 5|t=5T|acc=200%}}"),
               status_effect(2, "{{status|Toxicosis|t=180s|acc=g}}")]

    text = "Inflict {{status|Death Sentence (Sariel) 5|t=5T|acc=200%}}.\nRaise foes' " \
           "{{status|Toxicosis|t=180s|acc=g}} lvl by 1."
    expected = [{ text: "Inflict " }, { text: "Death Sentence (Sariel) 5", effect: 1 },
                { text: ".\nRaise foes' " }, { text: "Toxicosis", effect: 2 }, { text: " lvl by 1." }]

    expect(segments(text, effects: effects)).to eq(expected)
  end

  it "gives a repeated status each of its effects in order" do
    effects = [status_effect(1, "{{status|Death Sentence (Sariel)}}"), status_effect(2, "{{status|Death Sentence (Sariel)}}")]

    result = segments("Against {{status|Death Sentence (Sariel)}} and {{status|Death Sentence (Sariel)}}", effects: effects)
    expect(result.filter_map { |segment| segment[:effect] }).to eq([1, 2])
  end

  it "keeps the status tooltip when no effect matches the mention" do
    expect(segments("Gain {{status|DA Up|a=35%|t=2T}}.")).to eq(
      [{ text: "Gain " }, { text: "DA Up", tooltip: "35% · 2T" }, { text: "." }]
    )
  end

  it "names the skills that skill templates point at" do
    lookup = lambda do |kind, page, position|
      { ["ability", "Sariel", 1] => "Scythe of Execution", ["support", "Katzelia", 4] => "Ascension" }[[kind, page, position]]
    end

    text = "Activate {{CharacterSkill2|Sariel|1}} after {{CharacterSupportSkill|page=Katzelia|no=4}}."
    expected = [{ text: "Activate " }, { text: "Scythe of Execution", skill: true }, { text: " after " },
                { text: "Ascension", skill: true }, { text: "." }]

    expect(segments(text, skill_name: lookup)).to eq(expected)
  end

  it "describes a skill it can't name instead of dropping it" do
    expect(segments("Activate {{CharacterSkill2|Yngwie (Yukata)|2}}.")).to eq(
      [{ text: "Activate " }, { text: "Yngwie (Yukata)'s skill 2", skill: true }, { text: "." }]
    )
  end

  it "renders the mechanic templates the descriptions use" do
    text = "Upon the chain burst {{ChainBurst|Dark|4}}: {{Revitalize|a=10%|cap=1000}} effect against foes with {{Petrified}}"
    expected = [{ text: "Upon the chain burst (Dark, 4-chain): " },
                { text: "Revitalize", tooltip: "10% · Healing cap: 1000" },
                { text: " effect against foes with Petrified" }]

    expect(segments(text)).to eq(expected)
  end

  it "keeps {{atkmod}} text from the weapon renderer" do
    expect(segments("1% boost to all allies' {{atkmod|ATK|m=u}}")).to eq(
      [{ text: "1% boost to all allies' " }, { text: "ATK", tooltip: "Modifier: U" }]
    )
  end
end
