# frozen_string_literal: true

# Editor-only collection endpoints over catalogue tables (weapons, characters,
# summons, ...). A controller declares what may be filtered, sorted, returned
# and faceted (AdminCollection::Definition); AdminCollection::Query parses the
# query string against that allowlist; this concern renders one page of flat
# rows with an ETag.
#
#   GET /admin/weapons?q=sword&filter[element]=1,2&filter[release_date][gte]=2024-01-01
#       &filter[no_skills]=true&sort=-updated_at,name_en&page=1&per=50
#       &fields=granblue_id,name_en&facets=element,rarity
#
# Every parameter is validated before any query runs: an unknown or malformed
# filter, sort, field or facet is a 422 with { error: }.
#
# GET /admin/weapons/schema describes the same Definition (plus writable
# fields, enum values and model validators) for the editor; see
# AdminCollection::Schema.
#
# Facets count values for the current filter set minus the facet's own filter,
# so the other values of a multi-select stay visible. NULL values are counted
# under "none", and list filters accept "none" to match NULL.
#
# The ETag is keyed on each source table's row count and max(updated_at).
# Anything that writes catalogue rows without callbacks (update_all,
# update_columns, raw SQL) must set updated_at itself, or editors get a stale
# 304. insert_all/upsert_all stamp it automatically.
module AdminCollection
  extend ActiveSupport::Concern

  DEFAULT_PER = 50
  MAX_PER = 200
  NONE = 'none'
  ETAG_VERSION = 1
  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  class InvalidQuery < StandardError; end

  included do
    class_attribute :admin_collection_definition, instance_writer: false

    rescue_from InvalidQuery do |e|
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  class_methods do
    def admin_collection(model, &)
      definition = Definition.new(model)
      definition.instance_eval(&)
      self.admin_collection_definition = definition
    end
  end

  private

  def render_admin_collection
    query = Query.new(admin_collection_definition, params)
    return unless stale?(etag: admin_collection_etag, public: false)

    total = query.filtered.count
    body = { results: query.rows, meta: query.meta(total) }
    body[:facets] = query.facet_counts if query.facets.any?

    render json: body
  end

  def render_admin_schema
    definition = admin_collection_definition
    return unless stale?(etag: [ETAG_VERSION, self.class.name, definition.schema_digest], public: false)

    render json: definition.schema
  end

  # Whole-table stats rather than the filtered rows', because facets count
  # rows outside the current filter. The query string is part of the key.
  def admin_collection_etag
    stats = admin_collection_definition.etag_models.map do |model|
      latest = model.maximum(:updated_at)&.utc&.iso8601(6) if model.column_names.include?('updated_at')
      [model.table_name, model.count, latest]
    end
    [ETAG_VERSION, self.class.name, request.query_parameters.to_query, stats]
  end
end
