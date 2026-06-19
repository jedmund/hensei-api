# frozen_string_literal: true

class GridCharacterRoleAssignment < ApplicationRecord
  belongs_to :grid_character, inverse_of: :grid_character_role_assignments
  belongs_to :grid_character_role, inverse_of: :grid_character_role_assignments

  validates :grid_character_role_id, uniqueness: { scope: :grid_character_id }
end
