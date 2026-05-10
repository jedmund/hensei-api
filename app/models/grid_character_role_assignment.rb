# frozen_string_literal: true

class GridCharacterRoleAssignment < ApplicationRecord
  belongs_to :grid_character
  belongs_to :grid_character_role

  validates :grid_character_role_id, uniqueness: { scope: :grid_character_id }
end
