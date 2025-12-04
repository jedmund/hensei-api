# frozen_string_literal: true

class GwEvent < ApplicationRecord
  include GranblueEnums

  has_many :crew_gw_participations, dependent: :destroy
  has_many :crews, through: :crew_gw_participations

  enum :element, ELEMENTS

  validates :name, presence: true
  validates :element, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :event_number, presence: true, uniqueness: true

  validate :end_date_after_start_date

  scope :upcoming, -> { where('start_date > ?', Date.current).order(start_date: :asc) }
  scope :past, -> { where('end_date < ?', Date.current).order(start_date: :desc) }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Date.current, Date.current) }

  def active?
    start_date <= Date.current && end_date >= Date.current
  end

  def upcoming?
    start_date > Date.current
  end

  def finished?
    end_date < Date.current
  end

  private

  def end_date_after_start_date
    return unless start_date.present? && end_date.present?

    errors.add(:end_date, 'must be after start date') if end_date < start_date
  end
end
