# frozen_string_literal: true

# Places an effect on a Wonder, in the game's order.
class WonderEffectLink < ApplicationRecord
  belongs_to :wonder, inverse_of: :wonder_effect_links
  belongs_to :wonder_effect

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 },
                       uniqueness: { scope: :wonder_id }
end
