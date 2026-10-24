# frozen_string_literal: true

##
# Chooses what the home page shows: running events with top parties per
# linked raid, upcoming events with the top parties from the last time each
# one ran, rising parties, staff picks, and teams using items that are new
# (released or uncapped) in the last 18 days. Returns records and ordered
# party ids; HomeController loads and renders them.
class HomeFeed
  PARTIES_PER_RAID = 6
  RISING_LIMIT = 9
  UPCOMING_WINDOW = 14.days
  UPCOMING_LIMIT = 3
  CURRENT_LIMIT = 6
  STAFF_PICKS_LIMIT = 12
  NEW_ITEMS_WINDOW = 18.days
  NEW_ITEMS_LIMIT = 10
  PARTIES_PER_ITEM = 6

  # Item catalogue models with their grid join table and foreign key
  ITEM_SOURCES = {
    'character' => [Character, GridCharacter, :character_id],
    'weapon' => [Weapon, GridWeapon, :weapon_id],
    'summon' => [Summon, GridSummon, :summon_id]
  }.freeze

  Section = Struct.new(:event, :previous_event, :raids, keyword_init: true)
  RaidSection = Struct.new(:raid, :party_ids, keyword_init: true)
  NewItem = Struct.new(:type, :item, :change, :party_ids, keyword_init: true)

  def self.call(**)
    new(**).call
  end

  def initialize(now: Time.current)
    @now = now
  end

  def call
    {
      current: current_sections,
      upcoming: upcoming_sections,
      rising: rising_ids,
      staff_picks: staff_picks,
      new_items: new_items
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
      limit: PARTIES_PER_RAID,
      now: @now
    )
    raids.map { |raid| RaidSection.new(raid: raid, party_ids: ranked.fetch(raid.id, [])) }
  end

  def rising_ids
    Party.where(visibility: 1).where('participation_score > 0')
         .order(participation_score: :desc, id: :asc).limit(RISING_LIMIT).pluck(:id)
  end

  # Items whose latest date (release, FLB, ULB or transcendence) is in the
  # last 18 days, newest first, each with the teams made since then that use
  # it. Items without such teams are included with no teams.
  def new_items
    since = @now.in_time_zone('Asia/Tokyo').to_date - NEW_ITEMS_WINDOW
    candidates = ITEM_SOURCES.flat_map do |type, (model, _grid, _fk)|
      model.where(latest_date: since..).order(latest_date: :desc).limit(NEW_ITEMS_LIMIT * 2).map { |item| [type, item] }
    end
    candidates.sort_by { |type, item| [-item.latest_date.jd, type, item.id] }.first(NEW_ITEMS_LIMIT).map do |type, item|
      NewItem.new(type: type, item: item, change: item_change(item), party_ids: parties_using(type, item))
    end
  end

  def parties_using(type, item)
    _model, grid, fk = ITEM_SOURCES[type]
    since = item.latest_date.in_time_zone('Asia/Tokyo').beginning_of_day
    # Only teams made since the release or uncap: older teams were built
    # around the item before it changed
    Party.where(visibility: 1)
         .where(id: grid.where(fk => item.id).select(:party_id))
         .where(created_at: since..)
         .order(Arel.sql('parties.participation_score DESC NULLS LAST, parties.created_at DESC, parties.id ASC'))
         .limit(PARTIES_PER_ITEM)
         .pluck(:id)
  end

  # What made the item new: its release or its most recent uncap.
  def item_change(item)
    return 'release' if item.release_date == item.latest_date

    %w[transcendence ulb flb].find { |kind| item.public_send(:"#{kind}_date") == item.latest_date } || 'release'
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
