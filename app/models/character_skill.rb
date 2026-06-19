# frozen_string_literal: true

class CharacterSkill < ApplicationRecord
  belongs_to :character, primary_key: :granblue_id, foreign_key: :character_granblue_id,
                         inverse_of: :character_skills
  has_many :character_skill_versions, -> { order(:ordinal) },
           dependent: :destroy, inverse_of: :character_skill

  enum :kind, { ability: 'ability', ougi: 'ougi', support: 'support' }

  validates :character_granblue_id, presence: true
  validates :kind, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :position, uniqueness: { scope: %i[character_granblue_id kind] }
end
