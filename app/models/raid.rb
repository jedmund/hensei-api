# frozen_string_literal: true

class Raid < ApplicationRecord
  # Party sizes the game has: solo, and 6-, 18- and 30-player raids.
  PLAYER_COUNTS = { 'solo' => 1, 'six' => 6, 'eighteen' => 18, 'thirty' => 30 }.freeze
  # Lowercase words joined by single hyphens, e.g. "lucilius-hard".
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  belongs_to :group, class_name: 'RaidGroup', foreign_key: :group_id

  has_many :event_raids, dependent: :destroy
  has_many :events, through: :event_raids

  # Route Evokers whose Evoking Solomonis expeditions run in this zone.
  has_many :solomonis_evokers, class_name: 'Character', foreign_key: :solomonis_zone_id,
                               inverse_of: :solomonis_zone, dependent: :restrict_with_error

  # Validations
  validates :name_en, presence: true
  # Shown where the group already is (Home's tabs, the raid picker), e.g. "Lv200"
  validates :short_name_en, :short_name_jp, length: { maximum: 64 }
  validates :slug, presence: true, uniqueness: true
  validates :slug, format: { with: SLUG_FORMAT }, allow_blank: true
  validates :group_id, presence: true
  validates :element, inclusion: { in: GranblueEnums::ELEMENTS.values }, allow_nil: true
  validates :level, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :player_count, inclusion: { in: PLAYER_COUNTS.values }
  # The game's ids for the boss (icon), its summon (thumbnail) and its quest (lobby art)
  validates :enemy_id, :summon_id, :quest_id, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # Filter scopes
  scope :by_element, ->(element) { where(element: element) if element.present? }
  scope :by_group, ->(group_id) { where(group_id: group_id) if group_id.present? }
  scope :by_difficulty, ->(difficulty) { joins(:group).where(raid_groups: { difficulty: difficulty }) if difficulty.present? }
  scope :by_hl, ->(hl) { joins(:group).where(raid_groups: { hl: hl }) if hl.present? }
  scope :by_extra, ->(extra) {
    if extra.present?
      joins(:group).where(
        'COALESCE(raids.extra, raid_groups.extra) = ?', ActiveModel::Type::Boolean.new.cast(extra)
      )
    end
  }
  scope :with_guidebooks, -> { joins(:group).where(raid_groups: { guidebooks: true }) }
  scope :ordered, -> { joins(:group).order('raid_groups.order ASC, raids.level DESC') }

  scope :solomonis_zones, -> { joins(:group).where(raid_groups: { content_mode: RaidGroup::SOLOMONIS }) }

  # True for an Evoking Solomonis zone.
  def solomonis_zone?
    group&.solomonis? || false
  end

  def effective_extra
    extra.nil? ? group.extra : extra
  end

  def blueprint
    RaidBlueprint
  end
end
