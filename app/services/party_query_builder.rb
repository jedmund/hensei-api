# frozen_string_literal: true

# PartyQueryBuilder is responsible for building an ActiveRecord query for parties
# by applying a series of filters, includes, and excludes based on request parameters.
# It is used to build both the general parties query and specialized queries (like
# for a user’s profile) while keeping the filtering logic DRY.
#
# Usage:
#   base_query = Party.includes(:user, :job, ... )  # a starting query
#   query_builder = PartyQueryBuilder.new(base_query, params: params, current_user: current_user, options: { default_status: 'active' })
#   final_query = query_builder.build
#
class PartyQueryBuilder
  # Initialize with a base query, a params hash, and the current user.
  # Options may include default filters like :default_status, default counts, and max values.
  def initialize(base_query, params:, current_user:, options: {})
    @base_query = base_query
    @params = params
    @current_user = current_user
    @options = options
  end

  # Builds the final ActiveRecord query by applying filters, includes, and excludes.
  #
  # Edge cases handled:
  # - If a parameter is missing or blank, default values are used.
  # - If no recency is provided, no date range is applied.
  # - If includes/excludes parameters are missing, those methods are skipped.
  #
  # Also applies a default status filter (if provided via options) using a dedicated callback.
  def build
    query = @base_query
    query = apply_filters(query)
    query = apply_default_status(query) if @options[:default_status]
    query = apply_privacy_settings(query)
    query = apply_includes(query, @params[:includes]) if @params[:includes].present?
    query = apply_excludes(query, @params[:excludes]) if @params[:excludes].present?
    query = apply_collection_filter(query) if @params[:collection_filter].present? && @current_user
    query.order(created_at: :desc)
  end

  private

  # Applies filtering conditions to the given query.
  # Combines generic filters (like element, raid_id, created_at) with object count ranges.
  #
  # Example edge case: If the request does not specify 'characters_count',
  # then the default (e.g. 3) will be used, with the upper bound coming from a constant.
  def apply_filters(query)
    query = apply_base_filters(query)
    query = apply_name_quality_filter(query)
    query = apply_user_quality_filter(query)
    query = apply_original_filter(query)
    query = apply_count_filters(query)

    query
  end

  # Example callback method: if no explicit status filter is provided, we may want
  # to force the query to include only records with a given default status.
  # This method encapsulates that behavior.
  def apply_default_status(query)
    query.where(status: @options[:default_status])
  end

  # Applies privacy settings based on whether the current user is an admin.
  # Also includes parties shared with the current user's crew.
  def apply_privacy_settings(query)
    # If the options say to skip privacy filtering (e.g. when viewing your own profile),
    # then return the query unchanged.
    return query if @options[:skip_privacy]

    # Admins can see everything
    return query if @current_user&.admin?

    # Build conditions for what the user can see:
    # 1. Public parties (visibility = 1)
    # 2. Parties shared with their crew (if they're in a crew)
    if @current_user&.crew
      # User is in a crew - include public parties OR parties shared with their crew
      query.where(<<-SQL.squish, 1, 'Crew', @current_user.crew.id)
        visibility = ? OR parties.id IN (
          SELECT party_id FROM party_shares
          WHERE shareable_type = ? AND shareable_id = ?
        )
      SQL
    else
      # User is not in a crew - only show public parties
      query.where('visibility = ?', 1)
    end
  end

  # Builds a hash of filtering conditions from the params.
  #
  # Uses guard clauses to ignore keys when a parameter is missing.
  def build_filters
    {
      element: (@params[:element].present? ? @params[:element].to_i : nil),
      raid_id: @params[:raid],
      created_at: build_date_range,
      full_auto: build_option(@params[:full_auto]),
      auto_guard: build_option(@params[:auto_guard]),
      charge_attack: build_option(@params[:charge_attack]),
      solo: build_option(@params[:solo]),
      boost_mod: (@params[:boost_mod] if @params[:boost_mod].present?),
      boost_side: (@params[:boost_side] if @params[:boost_side].present?)
    }.compact
  end

  # Returns a date range based on the 'recency' parameter.
  # If recency is not provided, returns nil so no date filter is applied.
  def build_date_range
    return nil unless @params[:recency].present?
    start_time = DateTime.current - @params[:recency].to_i.seconds
    start_time.beginning_of_day..DateTime.current
  end

  # Returns the count from the parameter or a default value if the parameter is blank.
  def build_count(value, default_value)
    value.blank? ? default_value : value.to_i
  end

  # Processes an option parameter.
  # Returns the integer value unless the value is blank or equal to -1.
  def build_option(value)
    value.to_i unless value.blank? || value.to_i == -1
  end

  # Applies "includes" filtering to the query based on a comma-separated string.
  # For each provided ID, it adds a condition using an EXISTS subquery.
  #
  # Edge case example: If an ID does not start with a known prefix,
  # grid_table_and_object_table returns [nil, nil] and the condition is skipped.
  def apply_includes(query, includes)
    includes.split(',').each do |id|
      grid_table, object_table = grid_table_and_object_table(id)
      next unless grid_table && object_table
      condition = <<-SQL.squish
        EXISTS (
          SELECT 1 FROM #{grid_table}
          JOIN #{object_table} ON #{grid_table}.#{object_table.singularize}_id = #{object_table}.id
          WHERE #{object_table}.granblue_id = ? AND #{grid_table}.party_id = parties.id
        )
      SQL
      query = query.where(condition, id)
    end
    query
  end

  # Applies "excludes" filtering to the query based on a comma-separated string.
  # Works similarly to apply_includes, but with a NOT EXISTS clause.
  def apply_excludes(query, excludes)
    excludes.split(',').each do |id|
      grid_table, object_table = grid_table_and_object_table(id)
      next unless grid_table && object_table
      condition = <<-SQL.squish
        NOT EXISTS (
          SELECT 1 FROM #{grid_table}
          JOIN #{object_table} ON #{grid_table}.#{object_table.singularize}_id = #{object_table}.id
          WHERE #{object_table}.granblue_id = ? AND #{grid_table}.party_id = parties.id
        )
      SQL
      query = query.where(condition, id)
    end
    query
  end

  # Applies base filtering conditions from build_filters to the query.
  # @param query [ActiveRecord::QueryMethods::WhereChain] The current query.
  # @return [ActiveRecord::Relation] The query with base filters applied.
  def apply_base_filters(query)
    query.where(build_filters)
  end

  # Applies the name quality filter to the query if the parameter is present.
  # @param query [ActiveRecord::QueryMethods::WhereChain] The current query.
  # @return [ActiveRecord::Relation] The query with the name quality filter applied.
  def apply_name_quality_filter(query)
    @params[:name_quality].present? ? query.where(name_quality) : query
  end

  # Applies the user quality filter to the query if the parameter is present.
  # @param query [ActiveRecord::QueryMethods::WhereChain] The current query.
  # @return [ActiveRecord::Relation] The query with the user quality filter applied.
  def apply_user_quality_filter(query)
    @params[:user_quality].present? ? query.where(user_quality) : query
  end

  # Applies the original filter to the query if the parameter is present.
  # @param query [ActiveRecord::QueryMethods::WhereChain] The current query.
  # @return [ActiveRecord::Relation] The query with the original filter applied.
  def apply_original_filter(query)
    @params[:original].present? ? query.where(original) : query
  end

  # Applies count filters to the query based on provided parameters or default options.
  # If apply_defaults is set in options, default ranges are applied.
  # Otherwise, count ranges are built from provided parameters.
  # @param query [ | ActiveRecord::QueryMethods::WhereChain] The current query.
  # @return [ActiveRecord::Relation] The query with count filters applied.
  def apply_count_filters(query)
    if @options[:apply_defaults]
      query.where(
        weapons_count: default_weapons_count..max_weapons,
        characters_count: default_characters_count..max_characters,
        summons_count: default_summons_count..max_summons
      )
    elsif count_filter_provided?
      query.where(build_count_conditions)
    else
      query
    end
  end

  # Determines if any count filter parameters have been provided.
  # @return [Boolean] True if any count filters are provided, false otherwise.
  def count_filter_provided?
    @params.key?(:weapons_count) || @params.key?(:characters_count) || @params.key?(:summons_count)
  end

  # Builds a hash of count conditions based on the count filter parameters.
  # @return [Hash] A hash with keys :weapons_count, :characters_count, and :summons_count.
  def build_count_conditions
    {
      weapons_count: build_range(@params[:weapons_count], max_weapons),
      characters_count: build_range(@params[:characters_count], max_characters),
      summons_count: build_range(@params[:summons_count], max_summons)
    }
  end

  # Constructs a range for a given count parameter.
  # @param param_value [String, nil] The count filter parameter value.
  # @param max_value [Integer] The maximum allowed value for the count.
  # @return [Range] A range from the provided count (or 0 if blank) to the max_value.
  def build_range(param_value, max_value)
    param_value.present? ? param_value.to_i..max_value : 0..max_value
  end

  # Filters parties to only include those where ALL grid items exist
  # in the current user’s collection with sufficient copy counts.
  # Characters use existence check (unique per user), weapons and summons
  # use count-based check (multiple copies allowed).
  def apply_collection_filter(query)
    user_id = @current_user.id

    # Characters: every grid character must exist in user’s collection
    query = query.where(<<-SQL.squish, user_id)
      NOT EXISTS (
        SELECT 1 FROM grid_characters gc
        WHERE gc.party_id = parties.id
        AND NOT EXISTS (
          SELECT 1 FROM collection_characters cc
          WHERE cc.user_id = ? AND cc.character_id = gc.character_id
        )
      )
    SQL

    # Weapons: user must own >= the count used in the party per weapon_id
    query = query.where(<<-SQL.squish, user_id)
      NOT EXISTS (
        SELECT 1 FROM grid_weapons gw
        WHERE gw.party_id = parties.id
        GROUP BY gw.weapon_id
        HAVING COUNT(*) > (
          SELECT COUNT(*) FROM collection_weapons cw
          WHERE cw.user_id = ? AND cw.weapon_id = gw.weapon_id
        )
      )
    SQL

    # Summons: same count-based logic
    query = query.where(<<-SQL.squish, user_id)
      NOT EXISTS (
        SELECT 1 FROM grid_summons gs
        WHERE gs.party_id = parties.id
        AND gs.friend IS NOT TRUE
        GROUP BY gs.summon_id
        HAVING COUNT(*) > (
          SELECT COUNT(*) FROM collection_summons cs
          WHERE cs.user_id = ? AND cs.summon_id = gs.summon_id
        )
      )
    SQL

    query
  end

  # Maps an ID’s first character to the corresponding grid table and object table names.
  #
  # For example:
  #   '3...' => %w[grid_characters characters]
  #   '2...' => %w[grid_summons summons]
  #   '1...' => %w[grid_weapons weapons]
  # Returns [nil, nil] for unknown prefixes.
  def grid_table_and_object_table(id)
    case id[0]
    when '3'
      %w[grid_characters characters]
    when '2'
      %w[grid_summons summons]
    when '1'
      %w[grid_weapons weapons]
    else
      [nil, nil]
    end
  end

  # Default values and maximum limits for counts.
  def default_weapons_count
    @options[:default_weapons_count] || 5
  end

  def default_characters_count
    @options[:default_characters_count] || 3
  end

  def default_summons_count
    @options[:default_summons_count] || 2
  end

  def max_weapons
    @options[:max_weapons] || 13
  end

  def max_characters
    @options[:max_characters] || 5
  end

  def max_summons
    @options[:max_summons] || 8
  end

  # Excludes parties with low-quality default names (Untitled and its remixes).
  def name_quality
    low_quality = [
      'Untitled',
      'Remix of Untitled',
      'Remix of Remix of Untitled',
      'Remix of Remix of Remix of Untitled',
      'Remix of Remix of Remix of Remix of Untitled',
      'Remix of Remix of Remix of Remix of Remix of Untitled',
      '無題',
      '無題のリミックス',
      '無題のリミックスのリミックス',
      '無題のリミックスのリミックスのリミックス',
      '無題のリミックスのリミックスのリミックスのリミックス',
      '無題のリミックスのリミックスのリミックスのリミックスのリミックス'
    ]
    joined_names = low_quality.map { |name| "'#{name}'" }.join(',')
    "name NOT IN (#{joined_names})"
  end

  # Stub method for user quality filtering.
  # Adjust as needed for your actual implementation.
  def user_quality
    'user_id IS NOT NULL'
  end

  # Excludes remixed parties. Uses the remix boolean flag rather than
  # source_party_id since nullified foreign keys leave orphaned remixes.
  def original
    'remix = false'
  end

  # Stub method for privacy filtering.
  # Here we assume that if the current user is not an admin, only public parties (visibility = 1) are returned.
  def privacy
    return nil if @current_user && @current_user.admin?

    'visibility = 1'
  end
end
