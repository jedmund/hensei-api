# frozen_string_literal: true

# The Odious summons' 5★ main auras. gbf.wiki/Belmervolk gives 3.0% per exorcision
# level at 5★, capped at exorcision lvl 20 (+60%), and golden 0ZA6Ak shows a 5★
# Belmervolk at 180% (taboo 330 = 150 + 180), so the base is 120%. The same scale holds
# for every Odious summon (their 0/3/4★ rows match Belmervolk's), but only Belmervolk and
# Nihuyvintae have a 5★ so far. Each row copies the summon's 4★ wording;
# data/summon_aura_data.json has the same rows so granblue:load_summon_aura_data keeps them.
class AddOdiousFiveStarAuras < ActiveRecord::Migration[8.0]
  SUMMONS = %w[2040446000 2040447000].freeze # Belmervolk, Nihuyvintae

  def up
    SummonAura.reset_column_information
    SummonAura.where(summon_granblue_id: SUMMONS, target: "odious_frame", slot: "main", uncap_level: 4,
                     transcendence_stage: 0).find_each do |four|
      SummonAura.find_or_initialize_by(summon_granblue_id: four.summon_granblue_id, slot: "main",
                                       uncap_level: 5, transcendence_stage: 0).update!(
        target: "odious_frame", element: four.element, value: 120, condition: four.condition,
        description_en: four.description_en.to_s.sub("100% boost", "120% boost").sub("Max: 150%", "Max: 180%"),
        description_jp: four.description_jp
      )
    end
  end

  def down
    SummonAura.where(summon_granblue_id: SUMMONS, slot: "main", uncap_level: 5, transcendence_stage: 0).delete_all
  end
end
