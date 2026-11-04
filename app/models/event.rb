# frozen_string_literal: true

# A game event: a name, a time window, a kind, an optional element, banner art
# and the raids it links to. Synced events land as drafts; only approved
# events are public.
class Event < ApplicationRecord
  include GranblueEnums
  include ExpiresHomeFeed

  IMAGE_PREFIX = 'events'

  # Recurring events whose header image doesn't change between runs. Each
  # series has an image at events/series/<series>.webp (from the series' wiki
  # page), and may have a Japanese one at events/series/<series>.ja.webp; they
  # are used when the event has no image of its own.
  SERIES = %w[
    unite_and_fight dread_barrage rise_of_the_beasts records_of_the_ten
    exo_ifrit_crucible exo_cocytus_crucible exo_vohu_manah_crucible
    exo_sagittarius_crucible exo_corow_crucible exo_diablo_crucible
  ].freeze

  # `element` is the boss's element. Players bring the element advantaged
  # against it: Water boss -> Earth teams, Fire -> Water, Earth -> Wind,
  # Wind -> Fire, Light <-> Dark. Keyed by GranblueEnums::ELEMENTS values.
  ADVANTAGE_AGAINST = { Water: :Earth, Fire: :Water, Earth: :Wind, Wind: :Fire, Light: :Dark, Dark: :Light }
                      .to_h { |boss, team| [ELEMENTS.fetch(boss), ELEMENTS.fetch(team)] }.freeze
  # Guild War dates are JST calendar days: Day 1 opens at 19:00 and the last
  # day runs to 23:59:59.
  GW_TIME_ZONE = 'Asia/Tokyo'
  GW_START_HOUR = 19
  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  enum :kind, { story_event: 0, rerun: 1, collab: 2, unite_and_fight: 3, dread_barrage: 4, farming: 5,
                alchemy: 6, other: 7, exo_crucible: 8, records_of_the_ten: 9 }, validate: true

  # Kinds themed around a boss element: they require an element, and their
  # home sections only show teams of the advantaged element(s).
  ELEMENT_THEMED_KINDS = %w[unite_and_fight dread_barrage exo_crucible records_of_the_ten].freeze
  enum :status, { draft: 0, approved: 1, hidden: 2 }, validate: true
  enum :element, ELEMENTS, validate: { allow_nil: true }
  # A second boss element, for runs whose bosses share two weaknesses (Records
  # of the Ten runs Fire and Dark together: Wind and Light bosses).
  enum :second_element, ELEMENTS, prefix: :second, validate: { allow_nil: true }

  has_many :event_raids, -> { order(:position) }, dependent: :destroy, inverse_of: :event
  has_many :raids, through: :event_raids
  has_many :featured_parties, dependent: :destroy
  # Crew Guild War scores hang off these; an event with any can't be destroyed.
  has_many :crew_gw_participations, dependent: :restrict_with_error
  has_many :crews, through: :crew_gw_participations

  validates :name_en, presence: true, length: { maximum: 255 }
  # Links, as units have them: a gbf.wiki title, a GameWith article id and a
  # Kamigame path under /グラブル/ (without .html), folder included: most events
  # are under イベント/, Exo Crucible under 神滅戦/
  normalizes :wiki_en, with: ->(title) { Granblue::WikiTitle.normalize(title) }
  validates :wiki_en, :kamigame, length: { maximum: 255 }
  validates :gamewith, format: { with: /\A\d+\z/, message: 'must be a GameWith article number' }, allow_blank: true
  validates :name_jp, length: { maximum: 255 }
  validates :starts_at, :ends_at, presence: true
  validates :series, inclusion: { in: SERIES }, allow_nil: true
  validates :element, presence: true, if: :element_themed?
  validates :event_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :event_number, uniqueness: { conditions: -> { where(kind: kinds[:unite_and_fight]) } },
                           allow_nil: true, if: :unite_and_fight?
  # The crew pages find a Guild War by its number.
  validates :event_number, presence: true, if: :unite_and_fight?
  validate :ends_after_start
  validate :second_element_pairs_with_element

  scope :current, ->(now = Time.current) { where('starts_at <= ? AND ends_at > ?', now, now) }
  scope :upcoming, ->(now = Time.current) { where('starts_at > ?', now) }
  scope :past, ->(now = Time.current) { where(ends_at: ..now) }
  # Ended within the last `days` JST days (counting from the start of today in JST).
  scope :recently_ended, lambda { |days: 7, now: Time.current|
    today = now.in_time_zone(GW_TIME_ZONE).beginning_of_day
    where(ends_at: (today - days.days)..now).order(starts_at: :desc)
  }

  # Converts JST calendar days (Date or "YYYY-MM-DD") to a Guild War's
  # starts_at and ends_at, leaving out a blank one. Raises Date::Error on an
  # unparseable date.
  def self.gw_window(start_date, end_date)
    zone = Time.find_zone!(GW_TIME_ZONE)
    at = lambda do |value, *time|
      day = value.is_a?(Date) ? value : Date.parse(value.to_s)
      zone.local(day.year, day.month, day.day, *time)
    end
    window = {}
    window[:starts_at] = at.call(start_date, GW_START_HOUR) if start_date.present?
    window[:ends_at] = at.call(end_date, 23, 59, 59) if end_date.present?
    window
  end

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

  # The Japanese banner: the event's own, else its series' Japanese one. A
  # series may not have one yet, so clients fall back to banner_key when it
  # doesn't load.
  def banner_key_jp
    image_key_jp.presence || (series && "#{IMAGE_PREFIX}/series/#{series}.ja.webp")
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

  # First and last JST calendar days, as Guild War pages show them.
  def start_date
    starts_at&.in_time_zone(GW_TIME_ZONE)&.to_date
  end

  def end_date
    ends_at&.in_time_zone(GW_TIME_ZONE)&.to_date
  end

  def active?(now = Time.current)
    starts_at <= now && ends_at > now
  end

  def upcoming?(now = Time.current)
    starts_at > now
  end

  def finished?(now = Time.current)
    ends_at <= now
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

  # Every element teams can bring (integers): the advantage against each boss
  # element. Empty without an element.
  def advantage_elements
    [advantage_element, self.class.advantage_for(second_element_value)].compact
  end

  # The element as its integer value (GranblueEnums::ELEMENTS), as the API
  # emits it.
  def element_value
    element.nil? ? nil : self.class.elements[element]
  end

  # The second element as its integer value, or nil.
  def second_element_value
    second_element.nil? ? nil : self.class.second_elements[second_element]
  end

  private

  def ends_after_start
    return unless starts_at && ends_at

    errors.add(:ends_at, 'must be after starts_at') if ends_at <= starts_at
  end

  # A second element needs a first, a different one, and a real element (the
  # Null element has no advantage to bring).
  def second_element_pairs_with_element
    return if second_element.nil?

    if element.nil?
      errors.add(:second_element, 'needs an element')
    elsif second_element == element
      errors.add(:second_element, 'must differ from element')
    elsif second_element == 'Null'
      errors.add(:second_element, 'must be a real element')
    end
  end
end
