# frozen_string_literal: true

##
# An Arcarum Blessing for Evoking Solomonis (catalogue). Each blessing has
# levels that change its effect and cost; a party equips at most one level of
# each, with a total cost of at most COST_LIMIT.
class ArcarumBlessing < ApplicationRecord
  # The loadout cost limit. The same for every account; the API exposes it
  # with the catalogue so clients don't hard-code it.
  COST_LIMIT = 100

  SLUGS = %w[justice hanged_man death temperance devil tower star moon sun judgement].freeze
  # Unseals weapon position 2 at the start of an expedition.
  JUSTICE = 'justice'
  # Brings one character of the player's choice.
  HANGED_MAN = 'hanged_man'

  has_many :levels, -> { order(:level) }, class_name: 'ArcarumBlessingLevel',
                                          dependent: :destroy, inverse_of: :arcarum_blessing
  has_many :party_blessings, dependent: :restrict_with_error

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z_]+\z/ }
  validates :arcana_number, presence: true, uniqueness: true, numericality: { only_integer: true }
  validate :name_present

  scope :ordered, -> { order(:arcana_number) }
  scope :released, -> { where(released: true) }

  private

  def name_present
    errors.add(:name_en, 'or name_jp must be present') if name_en.blank? && name_jp.blank?
  end
end
