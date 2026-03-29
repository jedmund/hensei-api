# frozen_string_literal: true

class Event < ApplicationRecord
  EVENT_TYPES = %w[
    unite_and_fight
    rise_of_the_beasts
    tales_of_arcarum
    records_of_the_ten
    exo_crucible
    scenario_event
    collab_event
    dread_barrage
    scenario_rerun
    tower_of_babyl
  ].freeze

  validates :name, presence: true
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :element, inclusion: { in: 0..6 }, allow_nil: true

  validate :end_time_after_start_time

  scope :current, -> { where('start_time <= ? AND end_time >= ?', Time.current, Time.current) }
  scope :upcoming, -> { where('start_time > ?', Time.current).order(start_time: :asc) }
  scope :past, -> { where('end_time < ?', Time.current).order(start_time: :desc) }
  scope :by_type, ->(type) { where(event_type: type) if type.present? }

  def active?
    start_time <= Time.current && end_time >= Time.current
  end

  def status
    if active?
      'active'
    elsif start_time > Time.current
      'upcoming'
    else
      'finished'
    end
  end

  private

  def end_time_after_start_time
    return unless start_time.present? && end_time.present?

    errors.add(:end_time, 'must be after start time') if end_time < start_time
  end
end
