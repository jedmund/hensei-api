# frozen_string_literal: true

class WeaponCountGroup < ApplicationRecord
  has_many :weapon_count_group_memberships, dependent: :destroy
  has_many :weapons, through: :weapon_count_group_memberships

  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }
  validates :name_en, presence: true

  def display_resource(group)
    group.name_en
  end
end
