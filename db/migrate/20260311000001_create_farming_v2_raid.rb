# frozen_string_literal: true

class CreateFarmingV2Raid < ActiveRecord::Migration[7.1]
  def up
    return if Raid.exists?(slug: 'farming-v2')

    farming_group = RaidGroup.find_by(name_en: 'Farming')
    return unless farming_group

    Raid.create!(
      name_en: 'Farming (V2)',
      name_jp: '周回 (V2)',
      level: nil,
      element: 0,
      group: farming_group,
      slug: 'farming-v2'
    )
  end

  def down
    Raid.find_by(slug: 'farming-v2')&.destroy
  end
end
