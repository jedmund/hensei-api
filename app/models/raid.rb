# frozen_string_literal: true

class Raid < ApplicationRecord
  belongs_to :group, class_name: 'RaidGroup', foreign_key: :group_id

  # Validations
  validates :name_en, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :group_id, presence: true
  validates :element, inclusion: { in: 0..6 }, allow_nil: true
  validates :level, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Filter scopes
  scope :by_element, ->(element) { where(element: element) if element.present? }
  scope :by_group, ->(group_id) { where(group_id: group_id) if group_id.present? }
  scope :by_difficulty, ->(difficulty) { joins(:group).where(raid_groups: { difficulty: difficulty }) if difficulty.present? }
  scope :by_hl, ->(hl) { joins(:group).where(raid_groups: { hl: hl }) if hl.present? }
  scope :by_extra, ->(extra) {
    if extra.present?
      joins(:group).where(
        "COALESCE(raids.extra, raid_groups.extra) = ?", ActiveModel::Type::Boolean.new.cast(extra)
      )
    end
  }
  scope :with_guidebooks, -> { joins(:group).where(raid_groups: { guidebooks: true }) }
  scope :ordered, -> { joins(:group).order('raid_groups.order ASC, raids.level DESC') }

  def effective_extra
    extra.nil? ? group.extra : extra
  end

  def blueprint
    RaidBlueprint
  end
end
