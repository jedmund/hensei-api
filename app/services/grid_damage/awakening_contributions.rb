# frozen_string_literal: true

module GridDamage
  # Weapon Awakening contributions (gbf.wiki/Weapon_Awakening). Awakening a weapon to a type
  # (Attack/Defense/Skill DMG/Multiattack/C.A./Healing) grants flat panel bonuses that
  # accumulate per level. These are added DIRECTLY to the panel — the summon-aura/Exalto
  # enhancement does NOT amplify them — so every contribution is flagged `amplifiable: false`.
  module AwakeningContributions
    module_function

    # Cumulative bonus by Awakening slug → level → { boost_type => value }. Levels run 1–4 on
    # regular weapons (1 = awakened, no bonus). Heal/Special types add nothing to the damage panel.
    BONUS = {
      "weapon-atk" => {
        2 => { "atk" => 15.0 }, 3 => { "atk" => 15.0 }, 4 => { "atk" => 40.0 }
      },
      "weapon-def" => {
        2 => { "hp" => 15.0 }, 3 => { "hp" => 15.0, "def" => 20.0 }, 4 => { "hp" => 40.0, "def" => 20.0 }
      },
      "weapon-skill" => {
        2 => { "skill_dmg_cap" => 10.0 },
        3 => { "skill_dmg_cap" => 10.0, "skill_dmg" => 20.0 },
        4 => { "skill_dmg_cap" => 25.0, "skill_dmg" => 20.0 }
      },
      "weapon-multi" => {
        2 => { "ta" => 5.0 }, 3 => { "da" => 20.0, "ta" => 5.0 }, 4 => { "da" => 20.0, "ta" => 10.0 }
      },
      "weapon-ca" => {
        2 => { "ca_dmg" => 20.0 },
        3 => { "ca_dmg" => 20.0, "ca_dmg_cap" => 10.0 },
        4 => { "ca_dmg" => 20.0, "ca_dmg_cap" => 10.0, "ca_supp" => 100_000.0 }
      }
    }.freeze

    # ATK awakening lands in the Normal frame (it sits on the "Might" line); the rest are
    # frame-agnostic additive lines.
    FRAME = { "atk" => "normal" }.freeze

    def for_party(party)
      slugs = Awakening.where(id: party.weapons.filter_map(&:awakening_id)).pluck(:id, :slug).to_h
      party.weapons.flat_map do |gw|
        slug = slugs[gw.awakening_id] or next []
        bonus = BONUS.dig(slug, gw.awakening_level.to_i) or next []
        bonus.map do |boost_type, value|
          Aggregator::Contribution.new(
            boost_type: boost_type, series: FRAME[boost_type], value: value,
            main_hand_only: false, mainhand: gw.mainhand, amplifiable: false
          )
        end
      end
    end
  end
end
