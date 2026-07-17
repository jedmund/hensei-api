# frozen_string_literal: true

module GridDamage
  # Weapon Awakening contributions (gbf.wiki/Weapon_Awakening). Awakening a weapon to a type
  # (Attack/Defense/Skill DMG/Multiattack/C.A./Healing) grants flat panel bonuses that
  # accumulate per level. These are added DIRECTLY to the panel — the summon-aura/Exalto
  # enhancement does NOT amplify them — so every contribution is flagged `amplifiable: false`.
  # The source-backed awakening tables intentionally live beside their evaluator.
  # rubocop:disable Metrics/ModuleLength
  module AwakeningContributions
    module_function

    # Cumulative bonus by Awakening slug → level → { boost_type => value }, per the Grand
    # table (gbf.wiki/Weapon_Awakening). Levels run 1–4 on regular weapons (1 = awakened,
    # no bonus). Cap bonuses DO surface on the panel (dAV5ds: Skill DMG Cap 95 needs Fist
    # of Destruction's +25) — the earlier "caps don't show" observations (Galilei, DMG Cap
    # stayed 20) were lines already sitting at their shared display cap.
    BONUS = {
      "weapon-atk" => {
        2 => { "atk" => 15.0 },
        3 => { "atk" => 15.0, "dmg_cap" => 5.0 },
        4 => { "atk" => 40.0, "dmg_cap" => 5.0 }
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
      },
      "weapon-heal" => {
        2 => { "heal_cap" => 10.0 },
        3 => { "heal_cap" => 10.0, "debuff_res" => 10.0 },
        4 => { "heal_cap" => 30.0, "debuff_res" => 10.0 }
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

    # World weapons run a 10-level PER-WEAPON table ({{Weapon/Awakening/<weapon>}}, keyed
    # here by name). Increments accumulate like the Celestial table. The five wiki tabs
    # share the EX Might +10 / HP +10 backbone and vary only by cap line.
    WORLD_NA_CAP = {
      2 => { "na_dmg_cap" => 2.0 }, 3 => { "ex_atk" => 5.0 }, 4 => { "hp" => 5.0 },
      5 => { "na_dmg_cap" => 2.0 }, 6 => { "ex_atk" => 5.0 }, 7 => { "hp" => 5.0 },
      8 => { "na_dmg_cap" => 2.0 }, 9 => { "na_dmg_cap" => 2.0 },
      10 => { "na_dmg_cap" => 2.0 }
    }.freeze
    WORLD_SKILL_CAP = {
      2 => { "skill_dmg_cap" => 4.0 }, 3 => { "ex_atk" => 5.0 }, 4 => { "hp" => 5.0 },
      5 => { "skill_dmg_cap" => 4.0 }, 6 => { "ex_atk" => 5.0 }, 7 => { "hp" => 5.0 },
      8 => { "skill_dmg_cap" => 4.0 }, 9 => { "skill_dmg_cap" => 4.0 },
      10 => { "skill_dmg_cap" => 4.0 }
    }.freeze
    WORLD_CA_CAP = {
      2 => { "ca_dmg_cap" => 4.0 }, 3 => { "ex_atk" => 5.0 }, 4 => { "hp" => 5.0 },
      5 => { "ca_dmg_cap" => 4.0 }, 6 => { "ex_atk" => 5.0 }, 7 => { "hp" => 5.0 },
      8 => { "ca_dmg_cap" => 4.0 }, 9 => { "ca_dmg_cap" => 4.0 },
      10 => { "ca_dmg_cap" => 4.0 }
    }.freeze
    WORLD_BY_WEAPON = {
      "Worldscathing Leon" => WORLD_NA_CAP,
      "Worldstorming Aetos" => WORLD_SKILL_CAP,
      "Worldbreaking Tauros" => WORLD_SKILL_CAP,
      "Worldvexing Angelos" => WORLD_NA_CAP,
      "Worldforging Moros" => WORLD_CA_CAP
    }.freeze

    # World awakening bonuses name an arbitrary specialty PAIR per weapon (the wiki
    # template's Label icons) — not the weapon's own type. They apply when the MC's
    # job wields either (SPhnLB: Angelos axe/staff matches Lancer Origin's axe).
    WORLD_SPECIALTIES = {
      "Worldscathing Leon" => %w[gun katana],
      "Worldstorming Aetos" => %w[dagger spear],
      "Worldbreaking Tauros" => %w[melee harp],
      "Worldforging Moros" => %w[sabre bow],
      "Worldvexing Angelos" => %w[axe staff]
    }.freeze

    # ATK awakening lands in the Normal frame (it sits on the "Might" line); the rest are
    # frame-agnostic additive lines.
    FRAME = { "atk" => "normal" }.freeze

    # Revans weapons run the 20-level {{Weapon/Awakening/revansmkII}} table (Mk II reaches
    # 20; base weapons stop at 15). Per-level increments; flat weapon-stat bonuses
    # (ATK +100/+300/+500, HP +10/+15) never surface on the panel. HDbPnu's Attack lv20
    # Agastia measures Might +35 (flat, normal line), EX Might +10, AND E. ATK +15 —
    # the wiki's lv16/18/20 "ATK +N%" entries are Elemental ATK (all via remove-and-diff).
    REVANS_BY_TYPE = {
      "weapon-atk" => {
        2 => { "atk" => 2.0 }, 3 => { "atk" => 2.0 }, 4 => { "atk" => 2.0 },
        6 => { "atk" => 3.0 }, 7 => { "atk" => 3.0 }, 8 => { "atk" => 3.0 }, 9 => { "atk" => 3.0 },
        11 => { "atk" => 4.0 }, 12 => { "atk" => 4.0 }, 13 => { "atk" => 4.0 }, 14 => { "atk" => 5.0 },
        16 => { "e_atk" => 2.0 }, 17 => { "ex_atk" => 5.0 }, 18 => { "e_atk" => 3.0 },
        19 => { "ex_atk" => 5.0 }, 20 => { "e_atk" => 10.0 }
      },
      "weapon-def" => {
        2 => { "hp" => 3.0 }, 3 => { "def" => 3.0 }, 4 => { "hp" => 4.0 }, 5 => { "hp" => 4.0 },
        6 => { "def" => 3.0 }, 7 => { "hp" => 6.0 }, 8 => { "hp" => 6.0 }, 9 => { "def" => 3.0 },
        10 => { "hp" => 8.0 }, 11 => { "hp" => 8.0 }, 12 => { "def" => 3.0 }, 13 => { "hp" => 8.0 },
        14 => { "hp" => 8.0 }, 15 => { "def" => 3.0 }, 16 => { "debuff_res" => 2.0 },
        17 => { "elem_reduc" => 2.0 }, 18 => { "debuff_res" => 3.0 }, 19 => { "elem_reduc" => 3.0 },
        20 => { "heal_cap" => 5.0 }
      },
      "weapon-special" => {
        4 => { "ca_dmg_cap" => 2.0 }, 5 => { "dmg_cap" => 1.0 }, 9 => { "ca_dmg_cap" => 3.0 },
        10 => { "dmg_cap" => 2.0 }, 14 => { "ca_dmg_cap" => 2.0 }, 15 => { "dmg_cap" => 2.0 },
        16 => { "ca_dmg_cap" => 3.0 }, 17 => { "skill_dmg_cap" => 2.0 }, 18 => { "na_dmg_cap" => 2.0 },
        19 => { "skill_dmg_cap" => 3.0 }, 20 => { "na_dmg_cap" => 2.0 }
      }
    }.freeze

    # Proven Weapons ({{Weapon/Awakening/ProvingGrounds}}) run to lv15. Flat
    # weapon ATK/HP stat bonuses are not boost-pane rows, so only percent panel
    # bonuses are emitted. Controlled captures: Dawn Rising Attack Lv15 shows the
    # +15 EX Might, and Ushumgal Special Lv15 shows the +5 Skill DMG Cap/+3 DMG Cap.
    PROVEN_BY_TYPE = {
      "weapon-atk" => {
        2 => { "ex_atk" => 1.0 }, 3 => { "ex_atk" => 1.0 }, 4 => { "ex_atk" => 1.0 },
        6 => { "ex_atk" => 1.0 }, 7 => { "ex_atk" => 1.0 }, 8 => { "ex_atk" => 1.0 },
        9 => { "ex_atk" => 1.0 }, 11 => { "ex_atk" => 2.0 }, 12 => { "ex_atk" => 2.0 },
        13 => { "ex_atk" => 2.0 }, 14 => { "ex_atk" => 2.0 }
      },
      "weapon-def" => {
        3 => { "def" => 2.0 }, 5 => { "def" => 2.0 }, 7 => { "def" => 2.0 },
        9 => { "def" => 2.0 }, 11 => { "def" => 4.0 }, 13 => { "def" => 4.0 },
        15 => { "def" => 4.0 }
      },
      "weapon-special" => {
        4 => { "skill_dmg_cap" => 1.0 }, 5 => { "dmg_cap" => 1.0 },
        9 => { "skill_dmg_cap" => 2.0 }, 10 => { "dmg_cap" => 1.0 },
        14 => { "skill_dmg_cap" => 2.0 }, 15 => { "dmg_cap" => 1.0 }
      }
    }.freeze

    # Exo weapons ({{Weapon/Awakening/Exo}}, 10 levels, two types). "Special" is the
    # Might/HP column — HDbPnu's non-MH Hamartia lv10 measures +20/+20 flat. "Attack"
    # is the MAIN-WEAPON-ONLY column (EX Might/DMG Cap plus a group-specific lv3/6/9
    # slot). Unmapped Exo names intentionally contribute no attack-awakening panel rows
    # until the wiki/tab grouping or a golden identifies their slot.
    EXO_BY_TYPE = {
      "weapon-special" => {
        2 => { "atk" => 5.0 }, 3 => { "hp" => 4.0 }, 4 => { "hp" => 4.0 }, 5 => { "atk" => 5.0 },
        6 => { "atk" => 5.0 }, 7 => { "hp" => 4.0 }, 8 => { "hp" => 4.0 }, 9 => { "atk" => 5.0 },
        10 => { "hp" => 4.0 }
      }
    }.freeze

    EXO_MAIN_SHARED = {
      2 => { "ex_atk" => 5.0 }, 4 => { "dmg_cap" => 5.0 }, 5 => { "ex_atk" => 5.0 },
      7 => { "ex_atk" => 5.0 }, 8 => { "ex_atk" => 5.0 }, 10 => { "dmg_cap" => 5.0 }
    }.freeze
    EXO_MAIN_BY_GROUP = {
      "ca_supp" => EXO_MAIN_SHARED.merge(
        3 => { "ca_supp" => 100_000.0 }, 6 => { "ca_supp" => 100_000.0 },
        9 => { "ca_supp" => 100_000.0 }
      ),
      "dmg_supp" => EXO_MAIN_SHARED.merge(
        3 => { "dmg_supp" => 10_000.0 }, 6 => { "dmg_supp" => 10_000.0 },
        9 => { "dmg_supp" => 10_000.0 }
      ),
      "na_dmg_cap" => EXO_MAIN_SHARED.merge(
        3 => { "na_dmg_cap" => 3.0 }, 6 => { "na_dmg_cap" => 3.0 },
        9 => { "na_dmg_cap" => 4.0 }
      ),
      "skill_dmg_cap" => EXO_MAIN_SHARED.merge(
        3 => { "skill_dmg_cap" => 5.0 }, 6 => { "skill_dmg_cap" => 5.0 },
        9 => { "skill_dmg_cap" => 5.0 }
      )
    }.freeze
    EXO_MAIN_GROUP_BY_WEAPON = {
      "Exo Ashavan" => "ca_supp",
      "Exo Ephialtes" => "ca_supp",
      "Exo Antaeus" => "dmg_supp",
      "Exo Hamartia" => "dmg_supp",
      "Exo Heliocentrum" => "dmg_supp",
      "Exo Kshathra" => "na_dmg_cap",
      "Exo Maitrah Karuna" => "na_dmg_cap",
      "Exo Pelion" => "na_dmg_cap",
      "Exo Australis" => "skill_dmg_cap",
      "Exo Aristarchus" => "skill_dmg_cap",
      "Exo Krodha" => "skill_dmg_cap",
      "Exo Evilenes" => "skill_dmg_cap"
    }.freeze

    def for_party(party, composition: nil)
      composition ||= GridComposition.for_party(party)
      awakenings = Awakening.where(id: party.weapons.filter_map(&:awakening_id)).index_by(&:id)
      party.weapons.flat_map do |gw|
        awakening = awakenings[gw.awakening_id] or next []
        # Character awakenings can end up attached to grid weapons (frontend data quirk)
        # — they are not weapon awakenings and contribute nothing to the panel.
        next [] unless awakening.object_type == "Weapon"

        slug = awakening.slug
        bonus = case gw.weapon&.weapon_series&.slug
                when "celestial"
                  # Celestial bonuses follow the weapon's specialty, like the weapon's own
                  # per-specialty skills (9JtcHY: Altruism weapon-atk lv5 shows with a
                  # staff MC; K4UydX: hidden for harp/melee Rising Force).
                  specialty = GridComposition::PROFICIENCY_NAME[gw.weapon.proficiency]
                  next [] unless Array(composition[:mc_specialties]).include?(specialty)

                  celestial_bonus(slug, gw.awakening_level.to_i)
                when "world"
                  pair = WORLD_SPECIALTIES[gw.weapon.name_en]
                  next [] if pair && !pair.intersect?(Array(composition[:mc_specialties]))

                  accumulate(WORLD_BY_WEAPON[gw.weapon.name_en], gw.awakening_level.to_i)
                when "revans"
                  accumulate(REVANS_BY_TYPE[slug], gw.awakening_level.to_i)
                when "proven"
                  accumulate(PROVEN_BY_TYPE[slug], gw.awakening_level.to_i)
                when "exo"
                  table = EXO_BY_TYPE[slug]
                  table = exo_main_table(gw.weapon.name_en, slug) if table.nil? && gw.mainhand
                  accumulate(table, gw.awakening_level.to_i)
                else BONUS.dig(slug, gw.awakening_level.to_i)
                end
        next [] unless bonus

        bonus.map do |boost_type, value|
          bt, frame = boost_type == "ex_atk" ? %w[atk ex] : [boost_type, FRAME[boost_type]]
          Aggregator::Contribution.new(
            boost_type: bt, series: frame, value: value,
            main_hand_only: false, mainhand: gw.mainhand, amplifiable: false,
            source_ids: [gw.id],
            source_label: { en: "#{awakening.name_en} Awakening Lv#{gw.awakening_level}",
                            ja: "#{awakening.name_jp}覚醒 Lv#{gw.awakening_level}" }
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

    def exo_main_table(weapon_name, slug)
      return nil unless slug == "weapon-atk"

      EXO_MAIN_BY_GROUP[EXO_MAIN_GROUP_BY_WEAPON[weapon_name]]
    end

    # Sum per-level increment tables up to the current level.
    def accumulate(increments, level)
      return nil unless increments && level >= 2

      (2..level).each_with_object(Hash.new(0.0)) do |l, acc|
        (increments[l] || {}).each { |k, v| acc[k] += v }
      end.presence
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
