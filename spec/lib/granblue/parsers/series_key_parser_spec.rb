# frozen_string_literal: true

require "rails_helper"

RSpec.describe Granblue::Parsers::SeriesKeyParser do
  # A trimmed Dark Opus-style key table: an explicit-value pendulum whose Skill prose follows a
  # self-closing <ref/> (the regression that ate β Pendulum), and a size-word pendulum.
  let(:wikitext) do
    <<~WIKI
      {|
      ! Pendulum !! Skill Icon !! Charge Attack Additional Effect & Skill !! Trade Materials
      |-
      !| {{itm|β Pendulum|nolink|large}}
      | [[File:icon.png|45px]]
      | <div><b>Charge Attack Additional Effect:</b></div>300% Bonus damage.<ref name="g"/><hr/><div><b>Skill:</b></div>50% boost to skill DMG cap<br/><div><b>Upgraded at level 210:</b></div>more {{tt|skill hit rate|tip}}
      | Materials
      |-
      !| {{itm|Pendulum of Strength|nolink|large}}
      | [[File:icon.png|45px]]
      | <div><b>Skill:</b></div>Big boost to weapon element allies' ATK based on how high HP is.<div><b>Charge Attack Additional Effect:</b></div>Restore HP.
      |}
    WIKI
  end

  it "extracts each key's name and Skill prose (and survives a self-closing <ref/>)" do
    result = described_class.parse(wikitext)

    expect(result).to contain_exactly(
      { name: "β Pendulum", skill_text: "50% boost to skill DMG cap" },
      { name: "Pendulum of Strength", skill_text: "Big boost to weapon element allies' ATK based on how high HP is." }
    )
  end

  it "ignores non-key tables" do
    expect(described_class.parse("{|\n! Foo !! Bar\n|-\n| a || b\n|}")).to be_empty
  end
end
