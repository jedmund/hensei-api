# frozen_string_literal: true

class WeaponCountGroupMembership < ApplicationRecord
  belongs_to :weapon_count_group
  belongs_to :weapon

  validates :weapon_id, uniqueness: { scope: :weapon_count_group_id }
end
