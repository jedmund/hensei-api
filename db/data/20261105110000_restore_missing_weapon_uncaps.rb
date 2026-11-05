# frozen_string_literal: true

# Sixteen weapons were stored as 3★ (no FLB/ULB) though the wiki uncaps them to 4★ or
# 5★, so a grid copy couldn't be uncapped past 3★. Their stat columns were also wrong:
# shifted a column (Psycho Syringe's ULB HP in max_hp), mixed up (Xeno Judgement Lyre's
# FLB HP in max_atk) or missing. Two Xeno weapons also carried the game's launch date
# as their release date.
#
# Values come from each weapon's cached wiki page (evo_max, 4star_date, 5star_date,
# release_date, hp2-4, atk2-4), copied here so this never reads the wiki. A stat the
# wiki leaves blank is stored as nil: Maverick has no published level-100 stats, and
# Vanguard arrives at 5★, so it only has level-200 stats. Rows that already have FLB
# are left alone, so edits made since aren't overwritten. GBF-229.
class RestoreMissingWeaponUncaps < ActiveRecord::Migration[8.0]
  LEVELS = { 4 => { max_level: 150, max_skill_level: 15 }, 5 => { max_level: 200, max_skill_level: 20 } }.freeze

  WEAPONS = {
    '1040614900' => { name: 'Merveilleux', stars: 4, flb_date: '2021-06-18', ulb_date: nil, release_date: '2021-06-18',
                      max_hp: 258, max_hp_flb: 310, max_hp_ulb: nil, max_atk: 2299, max_atk_flb: 2787, max_atk_ulb: nil },
    '1040110700' => { name: 'Thorny Rose', stars: 4, flb_date: '2018-07-18', ulb_date: nil, release_date: '2018-07-18',
                      max_hp: 240, max_hp_flb: 282, max_hp_ulb: nil, max_atk: 2385, max_atk_flb: 2775, max_atk_ulb: nil },
    '1040009300' => { name: 'Nagelring', stars: 4, flb_date: '2021-02-10', ulb_date: nil, release_date: '2016-10-31',
                      max_hp: 217, max_hp_flb: 260, max_hp_ulb: nil, max_atk: 2500, max_atk_flb: 3020, max_atk_ulb: nil },
    '1040315800' => { name: 'Zroa Yeshana', stars: 4, flb_date: '2022-11-17', ulb_date: nil, release_date: '2022-11-17',
                      max_hp: 250, max_hp_flb: 282, max_hp_ulb: nil, max_atk: 2335, max_atk_flb: 2820, max_atk_ulb: nil },
    '1040419100' => { name: 'Arson Blaze', stars: 4, flb_date: '2021-09-15', ulb_date: nil, release_date: '2021-09-15',
                      max_hp: 280, max_hp_flb: 339, max_hp_ulb: nil, max_atk: 2190, max_atk_flb: 2648, max_atk_ulb: nil },
    '1040422000' => { name: 'Flowering Twilight', stars: 4, flb_date: '2023-08-16', ulb_date: nil,
                      release_date: '2023-08-16',
                      max_hp: 294, max_hp_flb: 354, max_hp_ulb: nil, max_atk: 2118, max_atk_flb: 2567, max_atk_ulb: nil },
    '1040305600' => { name: 'Onyx Stormbringer', stars: 4, flb_date: '2023-07-12', ulb_date: nil,
                      release_date: '2016-06-09',
                      max_hp: 155, max_hp_flb: 213, max_hp_ulb: nil, max_atk: 2151, max_atk_flb: 2965, max_atk_ulb: nil },
    '1040805700' => { name: 'Xeno Judgement Lyre', stars: 4, flb_date: '2017-03-11', ulb_date: nil,
                      release_date: '2017-03-11',
                      max_hp: 219, max_hp_flb: 250, max_hp_ulb: nil, max_atk: 1994, max_atk_flb: 2329, max_atk_ulb: nil },
    '1040209400' => { name: 'Xeno Conviction Flashspear', stars: 4, flb_date: '2017-08-24', ulb_date: nil,
                      release_date: '2017-08-24',
                      max_hp: 232, max_hp_flb: 271, max_hp_ulb: nil, max_atk: 2079, max_atk_flb: 2427, max_atk_ulb: nil },
    '1040306200' => { name: 'Xeno Infernal Flamescythe', stars: 4, flb_date: '2017-02-15', ulb_date: nil,
                      release_date: '2017-02-15',
                      max_hp: 170, max_hp_flb: 199, max_hp_ulb: nil, max_atk: 2392, max_atk_flb: 2795, max_atk_ulb: nil },
    '1040408100' => { name: 'Magma Rush', stars: 4, flb_date: '2023-07-12', ulb_date: nil, release_date: '2016-06-09',
                      max_hp: 232, max_hp_flb: 330, max_hp_ulb: nil, max_atk: 1770, max_atk_flb: 2378, max_atk_ulb: nil },
    '1040618300' => { name: "Bakugo's Bracers", stars: 4, flb_date: '2024-01-12', ulb_date: nil,
                      release_date: '2024-01-12',
                      max_hp: 113, max_hp_flb: 139, max_hp_ulb: nil, max_atk: 2317, max_atk_flb: 2793, max_atk_ulb: nil },
    '1040422100' => { name: 'First Fright of the Mischief', stars: 4, flb_date: '2023-10-18', ulb_date: nil,
                      release_date: '2023-10-18',
                      max_hp: 330, max_hp_flb: 397, max_hp_ulb: nil, max_atk: 1940, max_atk_flb: 2354, max_atk_ulb: nil },
    '1040707500' => { name: 'Maverick', stars: 5, flb_date: '2018-02-22', ulb_date: '2018-02-22',
                      release_date: '2018-02-22',
                      max_hp: nil, max_hp_flb: 256, max_hp_ulb: 293, max_atk: nil, max_atk_flb: 2810, max_atk_ulb: 3210 },
    '1040509700' => { name: 'Psycho Syringe', stars: 5, flb_date: '2018-12-18', ulb_date: '2018-12-18',
                      release_date: '2018-12-18',
                      max_hp: 231, max_hp_flb: 270, max_hp_ulb: 309, max_atk: 2295, max_atk_flb: 2680, max_atk_ulb: 3065 },
    '1040214000' => { name: 'Vanguard', stars: 5, flb_date: '2020-05-19', ulb_date: '2020-05-19',
                      release_date: '2020-05-19',
                      max_hp: nil, max_hp_flb: nil, max_hp_ulb: 257, max_atk: nil, max_atk_flb: nil, max_atk_ulb: 3246 }
  }.freeze

  def up
    now = Time.current
    WEAPONS.each do |granblue_id, attrs|
      stars = attrs[:stars]
      Weapon.where(granblue_id: granblue_id, name_en: attrs[:name], flb: false).update_all(
        attrs.except(:name, :stars).merge(LEVELS.fetch(stars)).merge(flb: true, ulb: stars == 5, updated_at: now)
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'the old values were wrong'
  end
end
