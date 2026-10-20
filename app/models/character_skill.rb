# frozen_string_literal: true

class CharacterSkill < ApplicationRecord
  # Owned by a character row: a style shift shares its base's granblue_id but has its
  # own skills. character_granblue_id is kept, denormalized, for reporting.
  belongs_to :character, inverse_of: :character_skills
  has_many :character_skill_versions, -> { order(:ordinal) },
           dependent: :destroy, inverse_of: :character_skill

  enum :kind, { ability: 'ability', ougi: 'ougi', support: 'support' }

  before_validation { self.character_granblue_id = character.granblue_id if character }

  validates :character_granblue_id, presence: true
  validates :kind, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :position, uniqueness: { scope: %i[character_id kind] }
end
