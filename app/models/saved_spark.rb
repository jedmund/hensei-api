# frozen_string_literal: true

# A spark a user saved from the spark maker (hensei-svelte's
# features/spark/spark.ts): three ordered lists of catalogue granblue_ids,
# which one was sparked, and the draw count. The rules match spark.ts so a
# saved spark always loads back into the page unchanged.
class SavedSpark < ApplicationRecord
  COLUMNS = %w[characters moons summons].freeze
  # Character weapons start with 1, summons with 2
  ID_FORMATS = {
    'characters' => /\A1\d{9}\z/,
    'moons' => /\A1\d{9}\z/,
    'summons' => /\A2\d{9}\z/
  }.freeze
  # The spark maker's pools and seasons (features/spark/pools.ts)
  POOLS = %w[premium flash legend collab classic classic_ii classic_iii].freeze
  SEASONS = %w[valentines summer halloween holiday formal].freeze
  # Pools that never run a seasonal version
  SEASONLESS_POOLS = %w[collab classic classic_ii classic_iii].freeze
  MAX_PER_COLUMN = 60
  MAX_DRAWS = 99_999
  # Granblue Fantasy's release; earlier dates are typos
  EARLIEST_DATE = Date.new(2014, 3, 10)

  belongs_to :user

  validates :spark_date, presence: true
  validates :draws, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_DRAWS }
  validates :sparked_column, inclusion: { in: COLUMNS }, allow_nil: true
  validates :pool, inclusion: { in: POOLS }, allow_nil: true
  validates :season, inclusion: { in: SEASONS }, allow_nil: true
  validate :season_fits_pool
  validate :spark_date_in_range
  validate :items_valid
  validate :sparked_mark_valid

  scope :newest_first, -> { order(spark_date: :desc, created_at: :desc, id: :desc) }

  # The sparked item as { column:, index: }, or nil
  def sparked
    return nil if sparked_column.nil? || sparked_index.nil?

    { column: sparked_column, index: sparked_index }
  end

  private

  # A day of slack: the client's today can be ahead of the server's in UTC+ zones
  def spark_date_in_range
    return if spark_date.nil?

    errors.add(:spark_date, 'cannot be in the future') if spark_date > Date.current + 1
    errors.add(:spark_date, 'is too early') if spark_date < EARLIEST_DATE
  end

  def season_fits_pool
    errors.add(:season, 'is not offered on that pool') if season && SEASONLESS_POOLS.include?(pool)
  end

  def items_valid
    COLUMNS.each do |column|
      ids = self[column]
      next errors.add(column, 'must be a list') unless ids.is_a?(Array)

      errors.add(column, "can hold at most #{MAX_PER_COLUMN} items") if ids.size > MAX_PER_COLUMN
      errors.add(column, 'contains an invalid id') unless ids.all? { |id| ID_FORMATS[column].match?(id.to_s) }
    end
  end

  def sparked_mark_valid
    return if sparked_column.nil? && sparked_index.nil?
    return errors.add(:sparked, 'needs both a column and an index') if sparked_column.nil? || sparked_index.nil?
    return unless COLUMNS.include?(sparked_column)

    list = self[sparked_column]
    return if list.is_a?(Array) && sparked_index.between?(0, list.size - 1)

    errors.add(:sparked, 'must point at an item in its column')
  end
end
