# frozen_string_literal: true

class GridSummon < ApplicationRecord
  belongs_to :party,
             counter_cache: :weapons_count,
             inverse_of: :summons
  validates_presence_of :party

  def summon
    Summon.find(summon_id)
  end

  def blueprint
    GridSummonBlueprint
  end
end
