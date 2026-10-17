# frozen_string_literal: true

##
# Chooses what the home page shows: running events with top parties per
# linked raid, upcoming events with the top parties from the last time each
# one ran, rising parties and staff picks. Returns records and ordered party
# ids; HomeController loads and renders them.
#
# With a sticker, the event sections and Rising only include parties that
# have received that sticker at least once. Staff picks are never filtered.
class HomeFeed
  PARTIES_PER_RAID = 6
  RISING_LIMIT = 6
  UPCOMING_WINDOW = 14.days
  UPCOMING_LIMIT = 3
  CURRENT_LIMIT = 6
  STAFF_PICKS_LIMIT = 12

  Section = Struct.new(:event, :previous_event, :raids, keyword_init: true)
  RaidSection = Struct.new(:raid, :party_ids, keyword_init: true)

  def self.call(**)
    new(**).call
  end

  def initialize(sticker: nil, now: Time.current)
    @sticker = sticker
    @now = now
  end

  def call
    {
      current: current_sections,
      upcoming: upcoming_sections,
      rising: rising_ids,
      staff_picks: staff_picks
    }
  end

  # Approved events of the same kind that ended before `event` started and
  # share a raid with it (element-themed kinds such as Unite and Fight: the
  # same boss element).
  def self.previous_event(event)
    scope = Event.approved
                 .where(kind: event.kind)
                 .where('ends_at <= ?', event.starts_at)
                 .where.not(id: event.id)

    if event.element_themed?
      scope = scope.where(element: event.element) if event.element
    else
      raid_ids = event.event_raids.map(&:raid_id)
      return nil if raid_ids.empty?

      scope = scope.where(id: EventRaid.where(raid_id: raid_ids).select(:event_id))
    end

    scope.includes(event_raids: { raid: :group }).order(ends_at: :desc).first
  end

  private

  def events
    Event.approved.includes(event_raids: { raid: :group })
  end

  def current_sections
    events.current(@now).order(:starts_at).limit(CURRENT_LIMIT).map do |event|
      Section.new(event: event, raids: raid_sections(event, window_event: event))
    end
  end

  def upcoming_sections
    events.upcoming(@now)
          .where('starts_at <= ?', @now + UPCOMING_WINDOW)
          .order(:starts_at)
          .limit(UPCOMING_LIMIT)
          .map do |event|
      previous = self.class.previous_event(event)
      Section.new(event: event, previous_event: previous, raids: raid_sections(event, window_event: previous))
    end
  end

  def raid_sections(event, window_event:)
    raids = event.event_raids.map(&:raid)
    ranked = PartyParticipation::EventRanking.call(
      raid_ids: raids.map(&:id),
      window_event: window_event,
      element: event.element_themed? ? event.advantage_element : nil,
      sticker: @sticker,
      limit: PARTIES_PER_RAID,
      now: @now
    )
    raids.map { |raid| RaidSection.new(raid: raid, party_ids: ranked.fetch(raid.id, [])) }
  end

  def rising_ids
    scope = Party.where(visibility: 1).where('participation_score > 0')
    scope = scope.where(id: PartySticker.where(sticker_id: @sticker.id).select(:party_id)) if @sticker
    scope.order(participation_score: :desc, id: :asc).limit(RISING_LIMIT).pluck(:id)
  end

  # Eventless picks always show; picks tied to an event only while that
  # event is approved and hasn't ended.
  def staff_picks
    FeaturedParty.joins(:party)
                 .left_joins(:event)
                 .where(parties: { visibility: 1 })
                 .where('featured_parties.event_id IS NULL OR (events.status = ? AND events.ends_at > ?)',
                        Event.statuses[:approved], @now)
                 .order(:position, :created_at)
                 .limit(STAFF_PICKS_LIMIT)
                 .to_a
  end
end
