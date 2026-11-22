# frozen_string_literal: true

# The level cap at one evolution (uncap) of a Crucible Seal.
class WonderEvolutionCap < ApplicationRecord
  belongs_to :wonder, inverse_of: :evolution_caps

  validates :evolution, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                        uniqueness: { scope: :wonder_id }
  validates :max_level, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
