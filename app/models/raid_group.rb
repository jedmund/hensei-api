# frozen_string_literal: true

class RaidGroup < ApplicationRecord
  # Special content a group's parties carry. `solomonis`: Evoking Solomonis,
  # whose raids are zones and whose parties have a SolomonisExpedition.
  # `unite_and_fight`: Unite and Fight, where Crucible Seals don't apply.
  SOLOMONIS = 'solomonis'
  UNITE_AND_FIGHT = 'unite_and_fight'
  CONTENT_MODES = [SOLOMONIS, UNITE_AND_FIGHT].freeze
  # Where a group sits in the raid picker. Farming is 0.
  SECTIONS = { 'farming' => 0, 'raid' => 1, 'event' => 2, 'solo' => 3 }.freeze

  has_many :raids, class_name: 'Raid', foreign_key: :group_id, inverse_of: :group, dependent: :restrict_with_error

  # Validations
  validates :name_en, presence: true
  validates :name_jp, presence: true
  validates :order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :section, presence: true, inclusion: { in: SECTIONS.values }
  validates :difficulty, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :content_mode, inclusion: { in: CONTENT_MODES }, allow_nil: true

  # Scopes
  scope :ordered, -> { order(order: :asc) }
  scope :by_section, ->(section) { where(section: section) if section.present? }
  scope :by_difficulty, ->(difficulty) { where(difficulty: difficulty) if difficulty.present? }
  scope :hl_only, -> { where(hl: true) }
  scope :extra_only, -> { where(extra: true) }
  scope :with_guidebooks, -> { where(guidebooks: true) }
  scope :unlimited_only, -> { where(unlimited: true) }
  scope :solomonis, -> { where(content_mode: SOLOMONIS) }

  def solomonis?
    content_mode == SOLOMONIS
  end

  def unite_and_fight?
    content_mode == UNITE_AND_FIGHT
  end
end
