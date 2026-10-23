# frozen_string_literal: true

require "rails_helper"

RSpec.describe Granblue::Parsers::GameplayNotesParser do
  describe ".inline_boosts" do
    # The real Pendulum of Extremity ≥280 Effect cell (Dark Opus series page): four
    # "N% boost to X" clauses plus a {{tt|Amplify|Stacking: Special}} clause — the panel's
    # second-stack "N.A. Amp (Sp.)".
    let(:extremity) do
      "</b></div>40% boost to {{atkmod|ATK|m=ex}}<br/>7% boost to DMG cap<br/>" \
        "25% boost to double attack rate<br/>25% boost to triple attack rate.<br />" \
        "{{tt|Amplify|'''Stacking:''' Special}} normal attack DMG by 10%"
    end

    it "parses boost-to clauses and the Sp-stacked amplify clause" do
      expect(described_class.inline_boosts(extremity)).to contain_exactly(
        { boost_type: "atk", value: 40.0, series: "ex" },
        { boost_type: "dmg_cap", value: 7.0, series: nil },
        { boost_type: "da", value: 25.0, series: nil },
        { boost_type: "ta", value: 25.0, series: nil },
        { boost_type: "na_amp_sp", value: 10.0, series: nil }
      )
    end

    it "maps a plain (non-Special) amplify clause to the base amp boost" do
      expect(described_class.inline_boosts("{{tt|Amplify|seraphic}} normal attack DMG by 30%"))
        .to contain_exactly({ boost_type: "na_amp", value: 30.0, series: nil })
    end
  end
end
