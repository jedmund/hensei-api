# frozen_string_literal: true

class WeaponSeriesVariant < ApplicationRecord
  belongs_to :weapon_series
  has_many :weapons, dependent: :restrict_with_error

  enum :augment_type, { no_augment: 0, ax: 1, befoulment: 2 }, prefix: true
end
