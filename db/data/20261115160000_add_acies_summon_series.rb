# frozen_string_literal: true

# Adds the Acies summon series after Robur, where the game's series filter
# shows it, and moves its summons into it. Rerunnable: an existing Acies
# series keeps its place, and the summons are only reassigned.
class AddAciesSummonSeries < ActiveRecord::Migration[8.1]
  # granblue_id => name_en, checked before anything is written
  SUMMONS = {
    '2040457000' => 'Lodern',
    '2040462000' => 'Bastet',
    '2040463000' => 'Poppet Hareloom'
  }.freeze

  def up
    summons = SUMMONS.map do |granblue_id, name_en|
      Summon.find_by(granblue_id: granblue_id, name_en: name_en) ||
        raise("Missing Summon #{granblue_id} (#{name_en})")
    end

    SummonSeries.transaction do
      acies = SummonSeries.find_by(slug: 'acies') || create_after_robur
      Summon.where(id: summons.map(&:id)).update_all(summon_series_id: acies.id, updated_at: Time.current)
    end
  end

  def down
    # Nothing to undo: removing the series would orphan its summons.
  end

  private

  def create_after_robur
    robur = SummonSeries.find_by(slug: 'robur') || raise('Missing SummonSeries robur')
    order = robur.order + 1

    SummonSeries.where(order: order..).update_all(['"order" = "order" + 1, updated_at = ?', Time.current])
    SummonSeries.create!(slug: 'acies', name_en: 'Acies Series', name_jp: 'アキエスシリーズ', order: order)
  end
end
