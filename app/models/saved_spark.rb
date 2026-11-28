# frozen_string_literal: true

# A spark a user saved from the spark maker (hensei-svelte's
# features/spark/spark.ts): three ordered lists of catalogue granblue_ids,
# which of them were sparked, and the draw count. The rules match spark.ts so a
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
  # The day each Classic pool opened (CLASSIC_OPENED in pools.ts); before it,
  # its items were in the Premium pool
  POOL_OPENED = {
    'classic' => Date.new(2022, 3, 10),
    'classic_ii' => Date.new(2024, 3, 10),
    'classic_iii' => Date.new(2026, 3, 10)
  }.freeze
  MAX_PER_COLUMN = 60
  # A spark is 300 draws: one sparked item per 300 (DRAWS_PER_SPARK in spark.ts)
  DRAWS_PER_SPARK = 300
  # Replaced by sparked_marks; dropped in a later migration
  self.ignored_columns += %w[sparked_column sparked_index]
  MAX_DRAWS = 99_999
  # Granblue Fantasy's release; earlier dates are typos
  EARLIEST_DATE = Date.new(2014, 3, 10)

  belongs_to :user

  validates :spark_date, presence: true
  validates :draws, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_DRAWS }
  validates :pool, inclusion: { in: POOLS }, allow_nil: true
  validates :season, inclusion: { in: SEASONS }, allow_nil: true
  validate :season_fits_pool
  validate :pool_open_on_spark_date
  validate :spark_date_in_range
  validate :items_valid
  validate :sparked_marks_valid

  scope :newest_first, -> { order(spark_date: :desc, created_at: :desc, id: :desc) }

  # The sparked items as [{ 'column' =>, 'index' => }], in column order then
  # by index, each once
  def sparked_marks=(marks)
    list = marks.is_a?(Array) ? marks.map { |mark| normalize_mark(mark) } : marks
    super(list.is_a?(Array) ? list.uniq.sort_by { |mark| mark_order(mark) } : list)
  end

  # The first mark, for clients that know only one
  def sparked
    sparked_marks.first
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

  def pool_open_on_spark_date
    opened = POOL_OPENED[pool]
    return if opened.nil? || spark_date.nil? || spark_date >= opened

    errors.add(:pool, 'had not opened by the spark date')
  end

  def items_valid
    COLUMNS.each do |column|
      ids = self[column]
      next errors.add(column, 'must be a list') unless ids.is_a?(Array)

      errors.add(column, "can hold at most #{MAX_PER_COLUMN} items") if ids.size > MAX_PER_COLUMN
      errors.add(column, 'contains an invalid id') unless ids.all? { |id| ID_FORMATS[column].match?(id.to_s) }
    end
  end

  def sparked_marks_valid
    return errors.add(:sparked, 'must be a list') unless sparked_marks.is_a?(Array)

    allowed = draws.is_a?(Integer) ? draws / DRAWS_PER_SPARK : 0
    errors.add(:sparked, "allows one item per #{DRAWS_PER_SPARK} draws") if sparked_marks.size > allowed

    sparked_marks.each do |mark|
      column = mark.is_a?(Hash) ? mark['column'] : nil
      index = mark.is_a?(Hash) ? mark['index'] : nil
      next errors.add(:sparked, 'needs a known column') unless COLUMNS.include?(column)

      list = self[column]
      next if index.is_a?(Integer) && list.is_a?(Array) && index.between?(0, list.size - 1)

      errors.add(:sparked, 'must point at an item in its column')
    end
  end

  # { column:, index: } with string or symbol keys, and the index as an
  # integer when it's one; anything else is kept as it came, to fail validation
  def normalize_mark(mark)
    return mark unless mark.respond_to?(:to_h)

    hash = mark.to_h.transform_keys(&:to_s)
    index = hash['index']
    index = index.to_i if index.is_a?(String) && index.match?(/\A\d+\z/)
    { 'column' => hash['column'], 'index' => index }
  end

  def mark_order(mark)
    [COLUMNS.index(mark['column']) || COLUMNS.size, mark['index'].is_a?(Integer) ? mark['index'] : 0]
  end
end
