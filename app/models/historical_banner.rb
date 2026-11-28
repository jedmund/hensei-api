# frozen_string_literal: true

# A past banner from gbf.wiki's Banner History, rebuilt by BannerHistory::Import
class HistoricalBanner < ApplicationRecord
  POOLS = %w[premium flash legend collab].freeze
  # Roles whose items count as the banner's rate-ups: what a gala rated up, what
  # another draw featured, a collab's own items. Zodiacs are available, not boosted.
  RATE_UP_ROLES = %w[rate_up featured collab].freeze
  ZONE = 'Asia/Tokyo'

  has_many :items, class_name: 'HistoricalBannerItem', dependent: :delete_all

  validates :key, :kind, :starts_at, :source_key, presence: true
  validates :pool, inclusion: { in: POOLS }

  # Banners running at any point of a day in Japan time; a banner still running has no end
  scope :on_day, lambda { |date|
    day = ActiveSupport::TimeZone[ZONE].parse(date.to_s).all_day
    where(starts_at: ..day.end).where('ends_at IS NULL OR ends_at >= ?', day.begin)
  }
end
