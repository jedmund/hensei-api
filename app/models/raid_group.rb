# frozen_string_literal: true

class RaidGroup < ApplicationRecord
  has_many :raids, class_name: 'Raid', foreign_key: :group_id, dependent: :restrict_with_error

  # Validations
  validates :name_en, presence: true
  validates :name_jp, presence: true
  validates :order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :section, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :difficulty, numericality: { only_integer: true }, allow_nil: true

  # Scopes
  scope :ordered, -> { order(order: :asc) }
  scope :by_section, ->(section) { where(section: section) if section.present? }
  scope :by_difficulty, ->(difficulty) { where(difficulty: difficulty) if difficulty.present? }
  scope :hl_only, -> { where(hl: true) }
  scope :extra_only, -> { where(extra: true) }
  scope :with_guidebooks, -> { where(guidebooks: true) }
  scope :unlimited_only, -> { where(unlimited: true) }

  def blueprint
    RaidGroupBlueprint
  end
end
