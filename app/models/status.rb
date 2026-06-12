# frozen_string_literal: true

class Status < ApplicationRecord
  has_many :skill_effects, dependent: :nullify

  enum :category, { buff: 'buff', debuff: 'debuff', field: 'field', special: 'special' }

  validates :name_en, presence: true
  validates :game_ailment_id, uniqueness: true, allow_nil: true

  scope :in_family, ->(name) { where(family: name) }

  # Splits a leveled status name ("Paralyzed 2") into [family, level].
  # Returns [nil, nil] when the name carries no trailing level.
  def self.split_family_and_level(name)
    match = name.to_s.match(/\A(.+?)\s+(\d+)\z/)
    return [nil, nil] unless match

    [match[1], match[2].to_i]
  end
end
