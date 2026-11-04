# frozen_string_literal: true

require 'rails_helper'

# Whether a skill has a skill level in game is a per-skill property: Fediel's Spine's
# Eclipse's Stamina has one, its Black Covenant doesn't.
RSpec.describe WeaponSkills::Build, '.scales?' do
  let(:registry_class) { WeaponSkills::Build::Rows::Registry }
  let(:registry) do
    curve = ->(attrs) { registry_class::Curve.new(boost_type: 'atk', formula_type: 'flat', **attrs) }
    registry_class.new(
      data: [curve.call(modifier: 'Might', series: 'normal', size: 'big', sl1: 6, sl10: 15, sl15: 18),
             curve.call(modifier: 'Stamina', boost_type: 'stamina', series: 'normal', size: 'big',
                        formula_type: 'stamina', coefficient: 56.4),
             curve.call(modifier: 'Omega Exalto', boost_type: 'omega_exalto', series: 'omega',
                        sl1: 20, sl10: 20, sl15: 20),
             curve.call(modifier: 'Pact', boost_type: 'dmg_supp', series: 'odious', size: 'big',
                        sl1: 4700, sl10: 6500, sl15: 7000)],
      effects: [registry_class::Effect.new(modifier: 'Voltage II', boost_type: 'ex_atk_sp'),
                registry_class::Effect.new(modifier: 'Pact', boost_type: 'dmg_supp')]
    )
  end

  def version(modifier, series: nil)
    WeaponSkills::BuildResult::Version.new(weapon_granblue_id: '1', position: 0, ordinal: 0,
                                           skill_name_en: 'x', skill_modifier: modifier, skill_series: series)
  end

  # Odious Pact's level table is its own; Hollowsky's EX Pact is a flat 50,000
  it "reads a family's levels from the skill's own series" do
    expect(described_class.scales?(version('Pact', series: 'odious'), registry)).to be(true)
    expect(described_class.scales?(version('Pact', series: 'ex'), registry)).to be(false)
  end

  it 'follows a family with values that change by skill level' do
    expect(described_class.scales?(version('Might'), registry)).to be(true)
  end

  it "counts a formula family that takes the skill level (Eclipse's Stamina)" do
    expect(described_class.scales?(version('Stamina'), registry)).to be(true)
  end

  it 'gives a fixed family no skill level (Exalto, Voltage II)' do
    expect(described_class.scales?(version('Omega Exalto'), registry)).to be(false)
    expect(described_class.scales?(version('Voltage II'), registry, 'Big boost to ATK')).to be(false)
  end

  it 'reads a skill with no family from its text' do
    expect(described_class.scales?(version(nil), registry, "Big boost to dark allies' ATK")).to be(true) # Armed Shadow
    expect(described_class.scales?(version(nil), registry,
                                   "Supplement dark allies' C.A. DMG based on how high HP is")).to be(false) # Black Covenant
    expect(described_class.scales?(version(nil), registry, "25% boost to allies' ATK")).to be(false)
  end
end
