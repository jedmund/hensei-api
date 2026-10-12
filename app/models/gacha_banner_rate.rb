# frozen_string_literal: true

# One item's displayed rate on a banner tab
class GachaBannerRate < ApplicationRecord
  CATEGORIES = %w[characterWeapon weapon summon].freeze

  belongs_to :gacha_banner

  validates :tab, inclusion: { in: [1, 2] }
  validates :rarity, inclusion: { in: [1, 2, 3] }
  validates :category, inclusion: { in: CATEGORIES }
  validates :reward_id, format: { with: /\A\d{10}\z/ }
  validates :percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
end
