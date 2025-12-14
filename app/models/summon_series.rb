# frozen_string_literal: true

class SummonSeries < ApplicationRecord
  has_many :summons, dependent: :restrict_with_error

  validates :name_en, presence: true
  validates :name_jp, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :order, numericality: { only_integer: true }

  scope :ordered, -> { order(:order) }

  # Slug constants for commonly referenced series
  PROVIDENCE = 'providence'
  GENESIS = 'genesis'
  MAGNA = 'magna'
  OPTIMUS = 'optimus'
  ARCARUM = 'arcarum'

  def blueprint
    SummonSeriesBlueprint
  end
end
