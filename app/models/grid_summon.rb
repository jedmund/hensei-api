# frozen_string_literal: true

class GridSummon < ApplicationRecord
  belongs_to :party

  def summon
    Summon.find(summon_id)
  end

  def blueprint
    GridSummonBlueprint
  end
end
