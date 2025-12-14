# frozen_string_literal: true

class CharacterSeries < ApplicationRecord
  has_many :character_series_memberships, dependent: :destroy
  has_many :characters, through: :character_series_memberships

  validates :name_en, presence: true
  validates :name_jp, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :order, numericality: { only_integer: true }

  scope :ordered, -> { order(:order) }

  # Slug constants for commonly referenced series
  STANDARD = 'standard'
  GRAND = 'grand'
  ZODIAC = 'zodiac'
  ETERNAL = 'eternal'
  EVOKER = 'evoker'
  SAINT = 'saint'

  def blueprint
    CharacterSeriesBlueprint
  end
end
