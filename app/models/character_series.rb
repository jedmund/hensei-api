# frozen_string_literal: true

class CharacterSeries < ApplicationRecord
  include Slugged

  has_many :character_series_memberships, dependent: :destroy
  has_many :characters, through: :character_series_memberships

  validates :name_en, presence: true
  validates :name_jp, presence: true
  validates :order, numericality: { only_integer: true }

  scope :ordered, -> { order(:order) }

  # Slug constants for commonly referenced series
  GRAND = 'grand'
  ZODIAC = 'zodiac'
  ETERNAL = 'eternal'
  EVOKER = 'evoker'
  SAINT = 'saint'
end
