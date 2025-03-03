# frozen_string_literal: true

class SkillValue < ApplicationRecord
  belongs_to :skill

  validates :level, presence: true, uniqueness: { scope: :skill_id }
end
