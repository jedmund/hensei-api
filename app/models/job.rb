# frozen_string_literal: true

class Job < ApplicationRecord
  include PgSearch::Model

  belongs_to :party, optional: true
  has_many :skills, class_name: 'JobSkill'

  multisearchable against: %i[name_en name_jp],
                  additional_attributes: lambda { |job|
                    {
                      name_en: job.name_en,
                      name_jp: job.name_jp,
                      granblue_id: job.granblue_id,
                      element: 0
                    }
                  }

  pg_search_scope :en_search,
                  against: :name_en,
                  using: {
                    tsearch: {
                      prefix: true
                    }
                  }

  pg_search_scope :ja_search,
                  against: :name_jp,
                  using: {
                    tsearch: {
                      prefix: true
                    }
                  }

  belongs_to :base_job,
             foreign_key: 'base_job_id',
             class_name: 'Job',
             optional: true

  # The game's job ids are 6 digits. A Class I job and its Class II successor
  # share one (Fighter and Warrior are both 100001), so ids are unique per row.
  GRANBLUE_ID_FORMAT = /\A\d{6}\z/

  # Rows as stored: Class I-V, Extra I and II, and Origin.
  ROWS = {
    "Class I": '1', "Class II": '2', "Class III": '3', "Class IV": '4', "Class V": '5',
    Extra: 'ex1', "Extra II": 'ex2', Origin: 'o1'
  }.freeze
  ACCESSORY_TYPES = { None: 0, Shield: 1, Manatura: 2 }.freeze
  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  # Simple rules the admin schema publishes (GET /admin/jobs/schema). Every job
  # has two proficiencies.
  PROFICIENCY_VALUES = GranblueEnums::PROFICIENCY.except(:None).freeze

  validates :granblue_id, presence: true, format: { with: GRANBLUE_ID_FORMAT }, uniqueness: { scope: :row }
  validates :name_en, :name_jp, presence: true
  validates :row, inclusion: { in: ROWS.values }
  validates :proficiency1, :proficiency2, inclusion: { in: PROFICIENCY_VALUES.values }
  validates :accessory_type, inclusion: { in: ACCESSORY_TYPES.values }
  validates :order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # A new job without an order goes last in its row.
  before_validation :assign_next_order, on: :create

  # A job by uuid, else by granblue_id. Class I and II jobs share a granblue_id,
  # so the uuid is the one that names a single job; granblue_id lookups stay for
  # older links and callers.
  def self.find_by_route_id(id)
    return if id.blank?

    (find_by(id: id) if id.to_s.match?(UUID_FORMAT)) || find_by(granblue_id: id)
  end

  def blueprint
    JobBlueprint
  end

  def display_resource(job)
    job.name_en
  end

  private

  def assign_next_order
    return unless order.nil? && row.present?

    self.order = (Job.where(row: row).maximum(:order) || 0) + 1
  end
end
