# frozen_string_literal: true

class GridCharacterRole < ApplicationRecord
  has_many :grid_character_role_assignments, dependent: :destroy, inverse_of: :grid_character_role
  has_many :grid_characters, through: :grid_character_role_assignments

  validates :name_en, presence: true
end
