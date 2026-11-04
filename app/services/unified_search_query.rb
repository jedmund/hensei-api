# frozen_string_literal: true

##
# Searches characters, weapons, summons and jobs at once through the
# pg_search multisearch documents, for typeaheads and mentions. Returns at
# most ten documents with their records.
#
# English runs a fuzzy (trigram) search first and falls back to a prefix
# search when that finds fewer than five; Japanese runs the prefix search.
# +exclude+ drops documents by granblue id.
class UnifiedSearchQuery
  LIMIT = 10
  FALLBACK_BELOW = 5
  MIN_QUERY_LENGTH = 2
  TRIGRAM = { trigram: { threshold: 0.3 } }.freeze
  TSEARCH_WITH_PREFIX = { tsearch: { prefix: true, dictionary: 'simple' } }.freeze

  def self.call(...) = new(...).call

  # @param params [#[]] search params with indifferent keys: query, exclude
  # @param locale [String] 'en' or 'ja'
  def initialize(params, locale:)
    @query = params[:query]
    @exclude = params[:exclude]
    @locale = locale
  end

  # @return [ActiveRecord::Relation] PgSearch::Document rows, loaded
  def call
    return search(TSEARCH_WITH_PREFIX) if @locale == 'ja'

    results = search(TRIGRAM)
    return results unless results.length < FALLBACK_BELOW && @query.to_s.length >= MIN_QUERY_LENGTH

    search(TSEARCH_WITH_PREFIX)
  end

  private

  # The multisearch options are process-wide, so each search sets its own
  def search(using)
    PgSearch.multisearch_options = { using: using }
    PgSearch.multisearch(@query).where.not(granblue_id: @exclude).includes(:searchable).limit(LIMIT)
  end
end
