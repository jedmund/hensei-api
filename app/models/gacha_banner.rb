# frozen_string_literal: true

# A draw banner from the game, with the rates it published
class GachaBanner < ApplicationRecord
  has_many :rates, class_name: 'GachaBannerRate', dependent: :delete_all

  validates :game_id, presence: true, uniqueness: true
  validates :starts_at, :ends_at, :fetched_at, presence: true

  # The latest banner that has started, ended or not: when a fetch fails the
  # last banner's rates stand in until the next one arrives
  def self.current(now = Time.current)
    where(starts_at: ..now).order(starts_at: :desc, fetched_at: :desc).first
  end

  def live?(now = Time.current)
    starts_at <= now && now < ends_at
  end
end
