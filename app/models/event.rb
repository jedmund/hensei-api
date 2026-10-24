# frozen_string_literal: true

# A game event: a name, a time window, a kind, an optional element, banner art
# and the raids it links to. Synced events land as drafts; only approved
# events are public.
class Event < ApplicationRecord
  include GranblueEnums

  IMAGE_PREFIX = 'events'

  # Recurring events whose header image doesn't change between runs. Each
  # series has one image at events/series/<series>.webp (from the series' wiki
  # page), used when the event has no image of its own.
  SERIES = %w[unite_and_fight dread_barrage rise_of_the_beasts records_of_the_ten].freeze

  # `element` is the boss's element. Players bring the element advantaged
  # against it (integer values from GranblueEnums::ELEMENTS): Water boss ->
  # Earth teams, Fire -> Water, Earth -> Wind, Wind -> Fire, Light <-> Dark.
  ADVANTAGE_AGAINST = { 3 => 4, 2 => 3, 4 => 1, 1 => 2, 6 => 5, 5 => 6 }.freeze
  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  enum :kind, { story_event: 0, rerun: 1, collab: 2, unite_and_fight: 3, dread_barrage: 4, farming: 5,
                alchemy: 6, other: 7 }, validate: true

  # Kinds themed around a boss element: they require an element, and their
  # home sections only show teams of the advantaged element.
  ELEMENT_THEMED_KINDS = %w[unite_and_fight dread_barrage].freeze
  enum :status, { draft: 0, approved: 1, hidden: 2 }, validate: true
  enum :element, ELEMENTS, validate: { allow_nil: true }

  has_many :event_raids, -> { order(:position) }, dependent: :destroy, inverse_of: :event
  has_many :raids, through: :event_raids
  has_many :featured_parties, dependent: :destroy

  validates :name_en, presence: true, length: { maximum: 255 }
  validates :name_jp, length: { maximum: 255 }
  validates :starts_at, :ends_at, presence: true
  validates :series, inclusion: { in: SERIES }, allow_nil: true
  validates :element, presence: true, if: :element_themed?
  validates :event_number, uniqueness: { conditions: -> { where(kind: kinds[:unite_and_fight]) } },
                           allow_nil: true, if: :unite_and_fight?
  validate :ends_after_start

  scope :current, ->(now = Time.current) { where('starts_at <= ? AND ends_at > ?', now, now) }
  scope :upcoming, ->(now = Time.current) { where('starts_at > ?', now) }
  scope :past, ->(now = Time.current) { where('ends_at <= ?', now) }

  # Accepts an element as its integer value (as the API emits it) or as its
  # enum name in any case ("fire", "Fire").
  def self.normalize_element(value)
    return nil if value.blank?

    if value.to_s.match?(/\A\d+\z/)
      elements.key(value.to_i) || value.to_s
    else
      elements.keys.find { |key| key.casecmp?(value.to_s) } || value
    end
  end

  # Bucket key of the banner to show: the event's own, else its series'.
  def banner_key
    image_key.presence || (series && "#{IMAGE_PREFIX}/series/#{series}.webp")
  end

  # Half-life used to decay stickers inside this event's section: half the
  # event's length.
  def sticker_half_life
    [(ends_at - starts_at) / 2.0, 1.hour.to_f].max
  end

  # Stickers count from when the event was announced (created here) or when
  # it started, whichever is earlier.
  def counting_since
    [created_at || starts_at, starts_at].min
  end

  # Replaces the linked raids, keeping the given order as positions. Returns
  # self, or nil (with errors on :raid_ids) when an id doesn't match a raid.
  def assign_raid_ids(raid_ids)
    ids = Array(raid_ids).compact_blank.map(&:to_s).uniq
    found = Raid.where(id: ids.grep(UUID_FORMAT)).pluck(:id)
    missing = ids - found
    if missing.any?
      errors.add(:raid_ids, "not found: #{missing.join(', ')}")
      return nil
    end

    transaction do
      event_raids.where.not(raid_id: ids).delete_all
      ids.each_with_index do |raid_id, index|
        row = event_raids.find_or_initialize_by(raid_id: raid_id)
        row.position = index
        row.save!
      end
    end
    event_raids.reset
    self
  end

  def element_themed?
    ELEMENT_THEMED_KINDS.include?(kind)
  end

  # The element advantaged against a boss element (integers), or nil.
  def self.advantage_for(boss_element)
    ADVANTAGE_AGAINST[boss_element]
  end

  # The element teams should bring (integer), or nil.
  def advantage_element
    self.class.advantage_for(element_value)
  end

  # The element as its integer value (GranblueEnums::ELEMENTS), as the API
  # emits it.
  def element_value
    element.nil? ? nil : self.class.elements[element]
  end

  private

  def ends_after_start
    return unless starts_at && ends_at

    errors.add(:ends_at, 'must be after starts_at') if ends_at <= starts_at
  end
end
