# frozen_string_literal: true

##
# Filters, text-searches and sorts a catalog model for the search endpoints.
# Subclasses name the model, its filters and its sort; the controller handles
# params, pagination and rendering.
#
# Filters are declared as data, param => filter, and apply when the param's
# value is present:
#
# - A Symbol is a column matched against the value, e.g. +series: :weapon_series_id+.
# - Filter.any_of(*columns) matches when any of the columns holds one of the
#   (integer) values, e.g. a proficiency in either slot.
# - Filter.scope(name) calls a model scope with the values.
# - Filter::PROMOTIONS matches rows sharing any of the promotions.
#
# A query of two or more characters runs the model's text search for the
# language (+en_search+ or +ja_search+), which orders by rank.
#
# @example
#   WeaponSearchQuery.call(params, locale: 'ja') # => Weapon relation
class CatalogSearchQuery
  Filter = Data.define(:kind, :target) do
    def self.any_of(*columns) = new(kind: :any_of, target: columns)
    def self.scope(name) = new(kind: :scope, target: name)
  end
  Filter::PROMOTIONS = Filter.new(kind: :promotions, target: :promotions)

  MIN_QUERY_LENGTH = 2
  SEARCH_SCOPES = { 'en' => :en_search, 'ja' => :ja_search }.freeze
  DEFAULT_ORDER = { latest_date: :desc, id: :asc }.freeze
  FILTERS = {}.freeze
  SORT = CatalogSort::ITEMS

  def self.call(...) = new(...).call

  # @param params [#[]] search params with indifferent keys: query, filters, sort, order
  # @param locale [String] 'en' or 'ja'
  def initialize(params, locale:)
    @params = params
    @locale = locale
  end

  # @return [ActiveRecord::Relation]
  def call
    sorted(filtered(searched(self.class::MODEL.all)))
  end

  private

  def searched(scope)
    text_query? ? scope.public_send(SEARCH_SCOPES.fetch(@locale), query) : scope
  end

  def filtered(scope)
    self.class::FILTERS.reduce(scope) do |result, (param, filter)|
      value = filter_value(param)
      value.present? ? apply_filter(result, filter, value) : result
    end
  end

  def apply_filter(scope, filter, value)
    case filter
    in Symbol then scope.where(filter => value)
    in Filter[kind: :any_of, target:] then target.map { |column| scope.where(column => integers(value)) }.reduce(:or)
    in Filter[kind: :scope, target:] then scope.public_send(target, Array(value))
    in Filter[kind: :promotions] then scope.where('promotions && ARRAY[?]::integer[]', integers(value))
    end
  end

  # A requested sort comes after the text search's rank
  def sorted(scope)
    return self.class::SORT.apply(scope, @params[:sort], @params[:order], @locale) if @params[:sort].present?

    default_order(scope)
  end

  # Newest first, unless a text search ranks the results
  def default_order(scope)
    query.blank? ? scope.order(DEFAULT_ORDER) : scope
  end

  def filter_value(param)
    filters = @params[:filters]
    filters && filters[param]
  end

  def query
    @params[:query]
  end

  def text_query?
    query.present? && query.to_s.length >= MIN_QUERY_LENGTH
  end

  def integers(value)
    Array(value).map(&:to_i)
  end
end
