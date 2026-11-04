# frozen_string_literal: true

##
# Filters and sorts a collection index: the items a user owns, or the catalog
# rows they don't own yet ("unowned" mode).
#
# The item type (see Api::V1::CollectionItemsController::ItemType) supplies the
# catalog model, preloads and per-type filters. Filters are declared as data,
# param => filter:
#
# - Owned items: a Symbol is a collection model scope called with the param's
#   comma-separated values, e.g. +proficiency: :by_proficiency+.
# - Unowned items: a Symbol is a catalog column matched against those values,
#   e.g. +series: :weapon_series_id+, and an Array of columns matches when any
#   of them does, e.g. +race: %i[race1 race2]+.
# - Filter.scope(name) calls a scope with the values in either mode.
# - Filter.exact(name) calls a scope with the raw, unsplit param.
# - Filter.flag(name) applies when the param is true: a no-argument scope on
#   owned items, or +name = true+ on unowned catalog rows.
#
# A filter applies whenever its param is given, even blank, as the endpoints
# always have.
#
# @example
#   query = CollectionItemQuery.new(CollectionWeaponsController.item_type,
#                                   owner: user, params: params, viewer: current_user)
#   query.owned   # => CollectionWeapon relation
#   query.unowned # => Weapon relation
class CollectionItemQuery
  Filter = Data.define(:kind, :target) do
    def self.scope(name) = new(kind: :scope, target: name)
    def self.exact(name) = new(kind: :exact, target: name)
    def self.flag(name) = new(kind: :flag, target: name)
  end

  OWNED_FILTERS = { element: :by_element, rarity: :by_rarity, series: :by_series }.freeze
  UNOWNED_FILTERS = { element: :element, rarity: :rarity }.freeze
  DEFAULT_UNOWNED_ORDER = [{ latest_date: :desc, id: :asc }].freeze

  # @param item_type [Api::V1::CollectionItemsController::ItemType]
  # @param owner [User] whose collection is listed
  # @param params [#[]] request params with symbol or indifferent keys
  # @param viewer [User, nil] the signed-in user, whose language sorts names
  def initialize(item_type, owner:, params:, viewer:)
    @item_type = item_type
    @owner = owner
    @params = params
    @viewer = viewer
  end

  # @return [ActiveRecord::Relation] the owner's items, filtered and sorted
  def owned
    scope = owner_items.includes(@item_type.owned_includes)
    scope = OWNED_FILTERS.merge(@item_type.owned_filters).reduce(scope) do |result, (param, filter)|
      @params[param].nil? ? result : filter_owned(result, param, filter)
    end
    scope = scope.by_name(@params[:search]) if @params[:search].present?
    scope.sorted_by(@params[:sort], language)
  end

  # @return [ActiveRecord::Relation] catalog rows the owner has no copy of, filtered and sorted
  def unowned
    owned_ids = owner_items.select(@item_type.foreign_key).distinct
    scope = @item_type.catalog.where.not(id: owned_ids).includes(@item_type.unowned_includes)
    scope = UNOWNED_FILTERS.merge(@item_type.unowned_filters).reduce(scope) do |result, (param, filter)|
      @params[param].nil? ? result : filter_unowned(result, param, filter)
    end
    scope = search_catalog(scope) if @params[:search].present?
    scope.order(*unowned_orders.fetch(@params[:sort], DEFAULT_UNOWNED_ORDER))
  end

  private

  def filter_owned(scope, param, filter)
    case filter
    in Symbol | Filter[kind: :scope] then scope.public_send(target(filter), values(param))
    in Filter[kind: :exact, target:] then scope.public_send(target, @params[param])
    in Filter[kind: :flag, target:] then flag?(param) ? scope.public_send(target) : scope
    end
  end

  def filter_unowned(scope, param, filter)
    case filter
    in Symbol then scope.where(filter => values(param))
    in Array then filter.map { |column| scope.where(column => values(param)) }.reduce(:or)
    in Filter[kind: :scope, target:] then scope.public_send(target, values(param))
    in Filter[kind: :exact, target:] then scope.where(target => @params[param])
    in Filter[kind: :flag, target:] then flag?(param) ? scope.where(target => true) : scope
    end
  end

  def search_catalog(scope)
    table = @item_type.catalog.table_name
    query = "%#{ActiveRecord::Base.sanitize_sql_like(@params[:search])}%"
    scope.where("#{table}.name_en ILIKE :q OR #{table}.name_jp ILIKE :q", q: query)
  end

  def unowned_orders
    name = "#{@item_type.catalog.table_name}.#{language == 'ja' ? 'name_jp' : 'name_en'}"
    orders = {
      'name_asc' => [Arel.sql("#{name} ASC NULLS LAST")],
      'name_desc' => [Arel.sql("#{name} DESC NULLS LAST")],
      'element_asc' => [{ element: :asc }],
      'element_desc' => [{ element: :desc }],
      'release_date_desc' => [Arel.sql('latest_date DESC NULLS LAST'), { id: :asc }],
      'release_date_asc' => [Arel.sql('latest_date ASC NULLS LAST'), { id: :asc }]
    }
    return orders unless (column = @item_type.proficiency_column)

    orders.merge('proficiency_asc' => [{ column => :asc }], 'proficiency_desc' => [{ column => :desc }])
  end

  def owner_items
    @owner.public_send(@item_type.association)
  end

  def target(filter)
    filter.is_a?(Filter) ? filter.target : filter
  end

  # Comma-separated values match any of them
  def values(param)
    @params[param].to_s.split(',')
  end

  def flag?(param)
    ActiveModel::Type::Boolean.new.cast(@params[param])
  end

  def language
    @viewer&.language || 'en'
  end
end
