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
    #
    # NOTE: awakening *cap* bonuses (Attack's "DMG Cap +5%", Skill DMG's "Skill DMG Cap +%",
    # C.A.'s "C.A. DMG Cap +%") do NOT surface on the "Weapon Skill Boosts" panel — confirmed
    # by the Galilei screenshots (DMG Cap stayed 20) and Twinpain (Skill DMG Cap stayed 50). They
    # apply to damage but aren't displayed here, so they're omitted until the damage phase.
    BONUS = {
      "weapon-atk" => {
        2 => { "atk" => 15.0 }, 3 => { "atk" => 15.0 }, 4 => { "atk" => 40.0 }
      },
      "weapon-def" => {
        2 => { "hp" => 15.0 }, 3 => { "hp" => 15.0, "def" => 20.0 }, 4 => { "hp" => 40.0, "def" => 20.0 }
      },
      "weapon-skill" => {
        2 => {}, 3 => { "skill_dmg" => 20.0 }, 4 => { "skill_dmg" => 20.0 }
      },
      "weapon-multi" => {
        2 => { "ta" => 5.0 }, 3 => { "da" => 20.0, "ta" => 5.0 }, 4 => { "da" => 20.0, "ta" => 10.0 }
      },
      "weapon-ca" => {
        2 => { "ca_dmg" => 20.0 },
        3 => { "ca_dmg" => 20.0 },
        4 => { "ca_dmg" => 20.0, "ca_supp" => 100_000.0 }
      }
    }.freeze

    # Celestial weapons use their own 5-level table ({{Weapon/Awakening/Celestial}}): EVERY
    # type grants Might +10 at lv2 (Normal frame) and EX Might +10 at lv3 (the panel's EX
    # Might line — "ex_atk" below); lv4/5 are type-specific. Values are per-level increments.
    # (5JPIJg: Twinpain's Skill DMG awakening explains the +10 Might AND +10 EX Might that
    # no weapon skill accounts for, and at lv5 the Skill DMG Cap 60 / Skill Supp +20000.)
    CELESTIAL_SHARED = { 2 => { "atk" => 10.0 }, 3 => { "ex_atk" => 10.0 } }.freeze
    CELESTIAL_BY_TYPE = {
      "weapon-atk"   => { 4 => { "ta" => 5.0 }, 5 => { "na_dmg_cap" => 5.0 } },
      "weapon-ca"    => { 4 => { "ca_dmg_cap" => 10.0 }, 5 => { "sp_ca_cap" => 5.0 } },
      "weapon-skill" => { 4 => { "skill_dmg_cap" => 10.0 }, 5 => { "skill_dmg_supp" => 20_000.0 } }
    }.freeze

    # ATK awakening lands in the Normal frame (it sits on the "Might" line); the rest are
    # frame-agnostic additive lines.
    FRAME = { "atk" => "normal" }.freeze

    def for_party(party)
      slugs = Awakening.where(id: party.weapons.filter_map(&:awakening_id)).pluck(:id, :slug).to_h
      party.weapons.flat_map do |gw|
        slug = slugs[gw.awakening_id] or next []
        bonus = if gw.weapon&.weapon_series&.slug == "celestial"
                  celestial_bonus(slug, gw.awakening_level.to_i)
                else
                  BONUS.dig(slug, gw.awakening_level.to_i)
                end
        next [] unless bonus

        bonus.map do |boost_type, value|
          bt, frame = boost_type == "ex_atk" ? ["atk", "ex"] : [boost_type, FRAME[boost_type]]
          Aggregator::Contribution.new(
            boost_type: bt, series: frame, value: value,
            main_hand_only: false, mainhand: gw.mainhand, amplifiable: false
          )
        end
      end
    end

    # Accumulate the celestial per-level increments up to the current level.
    def celestial_bonus(slug, level)
      return nil if level < 2

      (2..level).each_with_object({}) do |l, acc|
        acc.merge!(CELESTIAL_SHARED[l] || {})
        acc.merge!(CELESTIAL_BY_TYPE.dig(slug, l) || {})
      end
    end
  end
end
