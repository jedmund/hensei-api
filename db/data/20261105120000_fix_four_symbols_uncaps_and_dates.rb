# frozen_string_literal: true

# Four Symbols weapons (gbf.wiki, cached sources).
#
# Ray of Zhuque and Qinglong Spear stop at 4★: their 5★ forms are the separate Regus,
# Pontus and Malus upgrades. The base rows had picked up those upgrades' ULB flag, level
# 200 stats and SL20. They go back to 4★ (level 150, SL15) with no ULB stats. Grid and
# collection copies already saved at 5★ are left as they are; the lower cap only
# applies to new uncap changes.
#
# Dates: the eight base weapons carried the game's launch date (2014-03-10) as their
# release date and no FLB date, and Ray of Zhuque Pontus had no dates at all. Each
# date is only written while the row still holds the old value. GBF-229.
class FixFourSymbolsUncapsAndDates < ActiveRecord::Migration[8.0]
  LAUNCH_PLACEHOLDER = Date.new(2014, 3, 10)

  # granblue_id => name
  DEMOTE_TO_FLB = { '1040902500' => 'Ray of Zhuque', '1040204000' => 'Qinglong Spear' }.freeze

  # granblue_id => [name, release_date, flb_date, ulb_date]
  DATES = {
    '1040902500' => ['Ray of Zhuque', '2015-09-15', '2015-09-15', nil],
    '1040204000' => ['Qinglong Spear', '2016-01-14', '2016-01-14', nil],
    '1040303300' => ['Xuanwu Mace', '2015-12-11', '2015-12-11', nil],
    '1040603000' => ['Baihu Claw', '2016-02-24', '2016-02-24', nil],
    '1040805100' => ['Zhuque Lyrewings', '2016-06-23', '2016-06-23', nil],
    '1040008900' => ['Qinglong Manewhip', '2016-06-23', '2016-06-23', nil],
    '1040605800' => ['Xuanwu Shellfists', '2016-06-23', '2016-06-23', nil],
    '1040408600' => ['Baihu Fangstaff', '2016-06-23', '2016-06-23', nil],
    '1040906600' => ['Ray of Zhuque Pontus', '2017-04-10', '2017-04-10', '2022-04-07']
  }.freeze

  def up
    now = Time.current
    DEMOTE_TO_FLB.each do |granblue_id, name|
      Weapon.where(granblue_id: granblue_id, name_en: name, ulb: true)
            .update_all(ulb: false, max_level: 150, max_skill_level: 15, max_hp_ulb: nil, max_atk_ulb: nil,
                        ulb_date: nil, updated_at: now)
    end

    DATES.each do |granblue_id, (name, release_date, flb_date, ulb_date)|
      scope = Weapon.where(granblue_id: granblue_id, name_en: name)
      scope.where(release_date: [nil, LAUNCH_PLACEHOLDER]).update_all(release_date: release_date, updated_at: now)
      scope.where(flb_date: nil).update_all(flb_date: flb_date, updated_at: now)
      scope.where(ulb_date: nil).update_all(ulb_date: ulb_date, updated_at: now) if ulb_date
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'the old values were wrong'
  end
end
