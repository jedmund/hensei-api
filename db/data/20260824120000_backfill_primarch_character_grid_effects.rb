# frozen_string_literal: true

require Rails.root.join("lib/granblue/extractors/character_grid_effect_extractor")

# Rebuilds the twelve Primarch-style backline weapon-skill passives from their
# support descriptions. Keeping this data derived from the description makes the
# repair idempotent and lets the migration fail loudly if the source text changes
# into a form the parser no longer understands.
class BackfillPrimarchCharacterGridEffects < ActiveRecord::Migration[8.0]
  PASSIVES = {
    "3040440000" => { name: "Fotia Arche", element: "fire", frames: %w[normal omega], amount: 20.0 },
    "3040492000" => { name: "Hudor Arche", element: "water", frames: %w[normal omega], amount: 20.0 },
    "3040501000" => { name: "Gaia Arche", element: "earth", frames: %w[normal omega], amount: 20.0 },
    "3040568000" => { name: "Aeras Arche", element: "wind", frames: %w[normal omega], amount: 20.0 },
    "3040515000" => { name: "Selas Arche", element: "light", frames: %w[normal omega], amount: 20.0 },
    "3040611000" => { name: "Skotou Arche", element: "dark", frames: %w[normal omega], amount: 20.0 },
    "3040525000" => { name: "Emissary of Zhurong's Fire", element: "fire", frames: %w[omega], amount: 10.0 },
    "3040526000" => { name: "Emissary of Xuanming's Water", element: "water", frames: %w[omega], amount: 10.0 },
    "3040527000" => { name: "Emissary of Rushou's Earth", element: "earth", frames: %w[omega], amount: 10.0 },
    "3040528000" => { name: "Emissary of Goumang's Wind", element: "wind", frames: %w[omega], amount: 10.0 },
    "3040587000" => { name: "Emissary of Creation", element: "light", frames: %w[omega], amount: 10.0 },
    "3040571000" => { name: "Emissary of Annihilation", element: "dark", frames: %w[omega], amount: 10.0 }
  }.freeze
  EARTH_GRAND_ID = "3040312000"
  EXPECTED_CHARACTERS = 12
  EXPECTED_EFFECTS = 18

  def up
    extractor = Granblue::Extractors::CharacterGridEffectExtractor.new
    source_versions = validated_source_versions(extractor)

    canonical_effects.effect_weapon_skill_boost.delete_all
    earth_grand_effects.effect_weapon_skill_boost.delete_all
    created = source_versions.sum do |version, effects|
      next_ordinal = version.skill_effects.maximum(:ordinal).to_i
      effects.each_with_index do |attrs, index|
        version.skill_effects.create!(
          attrs.merge(ordinal: next_ordinal + index + 1, raw: version.description_en.to_s[0, 240])
        )
      end
      effects.size
    end

    raise "Expected #{EXPECTED_EFFECTS} Primarch passive effects, created #{created}" unless created == EXPECTED_EFFECTS

    audit_scope = canonical_effects.effect_weapon_skill_boost
    represented = audit_scope.joins(character_skill_version: :character_skill)
                             .distinct
                             .count("character_skills.character_granblue_id")
    unless audit_scope.count == EXPECTED_EFFECTS && represented == EXPECTED_CHARACTERS &&
           earth_grand_effects.effect_weapon_skill_boost.none?
      raise "Primarch passive audit failed: #{audit_scope.count} effects across #{represented} characters"
    end

    # This record had Light Grand Sandalphon's wiki source assigned to it. Correct
    # the page key here; refetching/reparsing the page remains an explicit deploy step.
    Character.where(granblue_id: EARTH_GRAND_ID).update_all(wiki_en: "Sandalphon (Earth Grand)")
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "the previous passive rows and incorrect Earth Grand wiki assignment cannot be restored safely"
  end

  private

  def canonical_effects
    SkillEffect.joins(character_skill_version: :character_skill)
               .where(character_skills: { character_granblue_id: PASSIVES.keys, kind: "support" })
  end

  def earth_grand_effects
    SkillEffect.joins(character_skill_version: :character_skill)
               .where(character_skills: { character_granblue_id: EARTH_GRAND_ID, kind: "support" })
  end

  def support_versions
    CharacterSkillVersion.joins(:character_skill)
                         .where(character_skills: { character_granblue_id: PASSIVES.keys, kind: "support" })
  end

  def validated_source_versions(extractor)
    PASSIVES.each_with_object({}) do |(granblue_id, expected), sources|
      character = Character.find_by(granblue_id: granblue_id)
      raise "Missing Primarch passive character #{granblue_id}" unless character

      actual_element = Granblue::Extractors::CharacterGridEffectExtractor::CHARACTER_ELEMENT_BY_ID[character.element]
      unless actual_element == expected[:element]
        raise "Element mismatch for #{granblue_id}: expected #{expected[:element]}, found #{actual_element.inspect}"
      end

      versions = support_versions.where(
        character_skills: { character_granblue_id: granblue_id }, name_en: expected[:name]
      ).to_a
      unless versions.one?
        raise "Expected one #{expected[:name]} version for #{granblue_id}, found #{versions.size}"
      end

      version = versions.first
      effects = extractor.extract(version.description_en, element: expected[:element])
      actual = effects.map { |effect| [effect[:frame], effect[:element], effect[:amount].to_f] }.sort
      wanted = expected[:frames].map { |frame| [frame, expected[:element], expected[:amount]] }.sort
      unless actual == wanted
        raise "Unexpected effects for #{granblue_id} #{expected[:name]}: #{actual.inspect}"
      end

      sources[version] = effects
    end
  end
end
