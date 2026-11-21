# frozen_string_literal: true

##
# A section of the in-game Wonders page (大事なもの), e.g. Crucible Seal.
# granblue_id is the game's category_id; category_type is the game's `type`
# (1 story, 2 Seals/Other/Rings of Fate, 3 Yupei).
class WonderCategory < ApplicationRecord
  has_many :wonders, -> { order(:sort_order) }, dependent: :restrict_with_error, inverse_of: :wonder_category

  validates :granblue_id, presence: true, uniqueness: true
  validates :name_en, presence: true
  validates :category_type, presence: true, numericality: { only_integer: true }

  scope :ordered, -> { order(:sort_order, :granblue_id) }
end
