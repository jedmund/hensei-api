class SupportSummon < ApplicationRecord
  belongs_to :user
  belongs_to :collection_summon

  has_one :summon, through: :collection_summon

  enum :section, { wind: 1, fire: 2, water: 3, earth: 4, dark: 5, light: 6, misc: 7 }

  validates :section, presence: true
  validates :position, presence: true
  validates :position, uniqueness: { scope: [:user_id, :section] }
  validate :position_within_section_bounds
  validate :collection_summon_belongs_to_user

  scope :ordered, -> { order(:section, :position) }
  scope :by_section, ->(section) { where(section: section) }

  def blueprint
    Api::V1::SupportSummonBlueprint
  end

  private

  def position_within_section_bounds
    return if position.nil? || section.nil?

    max = misc? ? 3 : 2
    return if position.between?(0, max)

    errors.add(:position, "must be between 0 and #{max} for #{section} section")
  end

  def collection_summon_belongs_to_user
    return if collection_summon.nil? || user_id.nil?
    return if collection_summon.user_id == user_id

    errors.add(:collection_summon, 'must belong to the same user')
  end
end
