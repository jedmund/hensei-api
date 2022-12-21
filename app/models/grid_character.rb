# frozen_string_literal: true

class GridCharacter < ApplicationRecord
  belongs_to :party

  def character
    Character.find(character_id)
  end
end
