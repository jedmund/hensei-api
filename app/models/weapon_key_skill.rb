# frozen_string_literal: true

# What a key does on one weapon: its skill there and the skill's upgrades, in the shape of
# weapon skill versions. Written by WeaponSkills::KeyOptions.build.
class WeaponKeySkill < ApplicationRecord
  belongs_to :weapon_key

  validates :weapon_granblue_id, presence: true, uniqueness: { scope: :weapon_key_id }
end
