# frozen_string_literal: true

class MarkAncestralNonSummonBoosted < ActiveRecord::Migration[8.0]
  def up
    WeaponSeries.find_by(slug: "ancestral")&.update!(summon_boosted: false)
  end

  def down
    WeaponSeries.find_by(slug: "ancestral")&.update!(summon_boosted: true)
  end
end
