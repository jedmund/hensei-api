# frozen_string_literal: true

# An item a past banner featured (HistoricalBanner)
class HistoricalBannerItem < ApplicationRecord
  ROLES = %w[rate_up featured collab zodiac pool].freeze

  belongs_to :historical_banner

  validates :granblue_id, :wiki_name, presence: true
  validates :item_type, inclusion: { in: %w[Weapon Summon] }
  validates :role, inclusion: { in: ROLES }
end
