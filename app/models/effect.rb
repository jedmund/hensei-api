# frozen_string_literal: true

class Effect < ApplicationRecord
  belongs_to :effect_family, class_name: 'Effect', optional: true
  has_many :child_effects, class_name: 'Effect', foreign_key: 'effect_family_id'
  has_many :skill_effects
  has_many :skills, through: :skill_effects

  validates :name_en, presence: true
  validates :effect_type, presence: true

  enum effect_type: { buff: 1, debuff: 2, special: 3 }

  scope :by_class, ->(effect_class) { where(effect_class: effect_class) }
  scope :stackable, -> { where(stackable: true) }
end
