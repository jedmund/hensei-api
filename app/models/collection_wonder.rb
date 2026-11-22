# frozen_string_literal: true

##
# A Wonder a user owns, with its in-game Active toggle. imported_bonuses keeps
# the bonus lines from the last import, for checking the computed bonuses.
class CollectionWonder < ApplicationRecord
  include WonderHolding

  belongs_to :user

  validates :wonder_id, uniqueness: { scope: :user_id }
  validates :active, inclusion: { in: [true, false] }

  scope :active, -> { where(active: true) }
  scope :ordered, lambda {
    joins(wonder: :wonder_category).order('wonder_categories.sort_order', 'wonders.sort_order')
  }
end
