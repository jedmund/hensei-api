# frozen_string_literal: true

class CharacterSeriesMembership < ApplicationRecord
  belongs_to :character
  belongs_to :character_series

  validates :character_id, uniqueness: { scope: :character_series_id }
end
