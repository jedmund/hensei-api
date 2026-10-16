# frozen_string_literal: true

# Belmervolk's 5★ main aura, which the wiki doesn't list yet. Golden 0ZA6Ak (4★ main,
# 5★ friend) shows Taboo 330% = 150 + 180, so the 5★ maximum is 180%. The 120% base
# assumes 3% per exorcision level, extending the page's 1/2/2.5% steps. The same row
# is in data/summon_aura_data.json so granblue:load_summon_aura_data keeps it.
class AddBelmervolkFiveStarAura < ActiveRecord::Migration[8.0]
  KEY = { summon_granblue_id: "2040446000", slot: "main", uncap_level: 5, transcendence_stage: 0 }.freeze

  def up
    SummonAura.reset_column_information
    SummonAura.find_or_initialize_by(KEY).update!(
      target: "odious_frame", element: nil, value: 120, condition: nil,
      description_en: "120% boost to Taboo Doomfire's weapon skills (Boost to specs based on equipped " \
                      "fire Odious weapons' exorcision lvl [Max: 180%])"
    )
  end

  def down
    SummonAura.where(KEY).delete_all
  end
end
