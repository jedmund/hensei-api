# frozen_string_literal: true

##
# Reference table for weapon stat modifiers (AX skills and befoulments).
#
# AX skills are positive modifiers that can be applied to certain weapons.
# Befoulments are negative modifiers that appear on Odiant weapons.
#
class WeaponStatModifier < ApplicationRecord
  CATEGORIES = %w[ax befoulment].freeze

  validates :slug, presence: true, uniqueness: true
  validates :name_en, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :polarity, inclusion: { in: [-1, 1] }

  scope :ax_skills, -> { where(category: 'ax') }
  scope :befoulments, -> { where(category: 'befoulment') }

  def self.find_by_game_skill_id(id)
    find_by(game_skill_id: id.to_i)
  end

  def buff?
    polarity == 1
  end

  def debuff?
    polarity == -1
  end
end
