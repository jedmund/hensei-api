# frozen_string_literal: true

##
# A Wonder on a team, as it was when the team was created
# (PartyWonderSnapshot) or as the owner set it. References the catalogue,
# never a collection row, so later collection changes don't reach the team.
class PartyWonder < ApplicationRecord
  include WonderHolding

  belongs_to :party, inverse_of: :party_wonders

  validates :wonder_id, uniqueness: { scope: :party_id }

  scope :ordered, lambda {
    joins(wonder: :wonder_category).order('wonder_categories.sort_order', 'wonders.sort_order')
  }
end
