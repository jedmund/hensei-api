# frozen_string_literal: true

class CharacterSkill < ApplicationRecord
  belongs_to :skill
  belongs_to :alt_skill, class_name: 'Skill', optional: true
  belongs_to :character, primary_key: 'granblue_id', foreign_key: 'character_granblue_id', optional: true

  validates :character_granblue_id, presence: true
  validates :position, presence: true
  validates :position, uniqueness: { scope: %i[character_granblue_id unlock_level] }

  scope :by_position, ->(position) { where(position: position) }
  scope :unlocked_at, ->(level) { where('unlock_level <= ?', level) }
  scope :improved_at, ->(level) { where('improve_level <= ?', level) }
end
