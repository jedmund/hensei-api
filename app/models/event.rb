class Event < ApplicationRecord
  EVENT_TYPES = {
    unite_and_fight: 0,
    rise_of_the_beasts: 1,
    tales_of_arcarum: 2,
    records_of_the_ten: 3,
    exo_crucible: 4,
    scenario_event: 5,
    collab_event: 6,
    dread_barrage: 7,
    scenario_rerun: 8,
    tower_of_babyl: 9
  }.freeze

  enum :event_type, EVENT_TYPES

  validates :name, presence: true
  validates :event_type, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :element, inclusion: { in: 0..6 }, allow_nil: true
  validate :end_time_after_start_time

  scope :current, -> { where('start_time <= ? AND end_time >= ?', Time.current, Time.current) }
  scope :upcoming, -> { where('start_time > ?', Time.current) }
  scope :past, -> { where('end_time < ?', Time.current) }
  scope :by_type, ->(type) { where(event_type: type) if type.present? }

  def status
    now = Time.current
    if start_time <= now && end_time >= now
      'current'
    elsif start_time > now
      'upcoming'
    else
      'past'
    end
  end

  private

  def end_time_after_start_time
    return unless start_time.present? && end_time.present?

    if end_time <= start_time
      errors.add(:end_time, 'must be after start time')
    end
  end
end
