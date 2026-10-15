# frozen_string_literal: true

require "rails_helper"

RSpec.describe Granblue::Extractors::ExpandedWeaponSkillImporter do
  describe ".main_hand_only_description?" do
    it "does not gate an always-on clause when only a later clause requires main hand" do
      description = "Boost to DEF for the first 8 turns / When main weapon: Reduce Poison damage"

      expect(described_class.send(:main_hand_only_description?, description)).to be(false)
    end
  end

  describe ".apply_gameplay_notes" do
    it "does not recreate version-linked Staff Resonance effects" do
      skill = instance_double(Skill, name_en: "Staff Resonance")
      version = instance_double(WeaponSkillVersion, skill: skill)
      slot = instance_double(WeaponSkill, weapon_skill_versions: [version])
      association = double(includes: [slot])
      weapon = instance_double(Weapon, weapon_skills: association)
      notes = {
        "Staff Resonance" => {
          frame: "ex", clauses: [{ scaling: :per_count, boost_type: "da", value: 1.0 }]
        }
      }
      allow(Granblue::Parsers::GameplayNotesParser).to receive(:parse).and_return(notes)
      expect(WeaponSkillEffect).not_to receive(:where)

      described_class.send(:apply_gameplay_notes, weapon, "expanded", Hash.new(0))
    end

    it "keeps curated rows and skips suppressed boost types" do
      version = create(:weapon_skill_version, suppressed_boosts: ["e_atk"])
      version.skill.update!(name_en: "Ultimate Wisdom's Shine")
      curated = WeaponSkillEffect.create!(weapon_skill_version: version, modifier: "Ultimate Wisdom's Shine",
                                          boost_type: "atk", scaling_kind: "specialty_scaled", value_unit: "percent",
                                          condition: { "specialties" => { "staff" => 20.0 } },
                                          manually_edited_at: Time.current, provenance: "manual")
      table = { "staff" => 10.0 }
      notes = {
        "Ultimate Wisdom's Shine" => {
          frame: "normal", clauses: [{ scaling: :per_specialty, boost_type: "atk", by_specialty: table },
                                     { scaling: :per_specialty, boost_type: "e_atk", by_specialty: table },
                                     { scaling: :per_specialty, boost_type: "da", by_specialty: table }]
        }
      }
      allow(Granblue::Parsers::GameplayNotesParser).to receive(:parse).and_return(notes)

      described_class.send(:apply_gameplay_notes, version.weapon_skill.weapon, "expanded", Hash.new(0))

      effects = WeaponSkillEffect.where(weapon_skill_version_id: version.id)
      expect(effects.pluck(:boost_type)).to contain_exactly("atk", "da")
      expect(effects.find_by(boost_type: "atk")).to eq(curated)
    end
  end
end
