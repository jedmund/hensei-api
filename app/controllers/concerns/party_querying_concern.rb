# frozen_string_literal: true

module PartyQueryingConcern
  extend ActiveSupport::Concern
  include PartyConstants

  # Builds the base query for parties with all required associations.
  def build_parties_query(favorites: false)
    query = Party.includes(
      { raid: :group },
      :job,
      :user,
      :skill0, :skill1, :skill2, :skill3,
      :guidebook1, :guidebook2, :guidebook3,
      { characters: :character },
      { weapons: :weapon },
      { summons: :summon }
    )
    query = if favorites
              query.joins(:favorites)
                   .where(favorites: { user_id: current_user.id })
                   .distinct.order(created_at: :desc)
            else
              query.order(visibility: :asc, created_at: :desc)
            end
    query = apply_filters(query)
    query = apply_privacy_settings(query, favorites: false)
    query = apply_includes(query, params[:includes]) if params[:includes].present?
    query = apply_excludes(query, params[:excludes]) if params[:excludes].present?
    query
  end

  # Renders paginated parties using PartyBlueprint.
  def render_paginated_parties(parties)
    render json: Api::V1::PartyBlueprint.render(
      parties,
      view: :preview,
      root: :results,
      meta: {
        count: parties.total_entries,
        total_pages: parties.total_pages,
        per_page: PartyConstants::COLLECTION_PER_PAGE
      },
      current_user: current_user
    )
  end

  # Applies filters to the query.
  def apply_filters(query)
    conditions = build_filters

    query = query.where(conditions)
    query = query.where(name_quality) if params[:name_quality].present?
    query.where(
      weapons_count: build_count(params[:weapons_count], PartyConstants::DEFAULT_MIN_WEAPONS)..PartyConstants::MAX_WEAPONS,
      characters_count: build_count(params[:characters_count], PartyConstants::DEFAULT_MIN_CHARACTERS)..PartyConstants::MAX_CHARACTERS,
      summons_count: build_count(params[:summons_count], PartyConstants::DEFAULT_MIN_SUMMONS)..PartyConstants::MAX_SUMMONS
    )
  end

  # Applies privacy settings based on whether the current user is an admin.
  def apply_privacy_settings(query, favorites: false)
    return query if admin_mode

    if favorites.present?
      query.where('visibility < 3')
    else
      query.where(visibility: 1)
    end
  end

  # Builds filtering conditions from request parameters.
  def build_filters
    {
      element: params[:element].present? ? params[:element].to_i : nil,
      raid_id: params[:raid],
      created_at: build_date_range,
      full_auto: build_option(params[:full_auto]),
      auto_guard: build_option(params[:auto_guard]),
      charge_attack: build_option(params[:charge_attack]),
      characters_count: build_count(params[:characters_count], PartyConstants::DEFAULT_MIN_CHARACTERS)..PartyConstants::MAX_CHARACTERS,
      summons_count: build_count(params[:summons_count], PartyConstants::DEFAULT_MIN_SUMMONS)..PartyConstants::MAX_SUMMONS,
      weapons_count: build_count(params[:weapons_count], PartyConstants::DEFAULT_MIN_WEAPONS)..PartyConstants::MAX_WEAPONS
    }.compact
  end

  # Returns a date range based on the recency parameter.
  def build_date_range
    return nil unless params[:recency].present?

    start_time = DateTime.current - params[:recency].to_i.seconds
    start_time.beginning_of_day..DateTime.current
  end

  # Returns the count value or a default if blank.
  def build_count(value, default)
    value.blank? ? default : value.to_i
  end

  # Processes an option parameter.
  def build_option(value)
    value.to_i unless value.blank? || value.to_i == -1
  end

  # Applies “includes” filtering for objects in the party.
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

  # Applies “excludes” filtering for objects in the party.
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

  # Maps an id’s prefix to the corresponding grid and object table names.
  def grid_table_and_object_table(id)
    case id[0]
    when '3' then %w[grid_characters characters]
    when '2' then %w[grid_summons summons]
    when '1' then %w[grid_weapons weapons]
    else [nil, nil]
    end
  end

  # Returns a remixed party name based on the current party name and current_user language.
  def remixed_name(name)
    blanked_name = { en: name.blank? ? 'Untitled team' : name, ja: name.blank? ? '無名の編成' : name }
    if current_user
      case current_user.language
      when 'en' then "Remix of #{blanked_name[:en]}"
      when 'ja' then "#{blanked_name[:ja]}のリミックス"
      else "Remix of #{blanked_name[:en]}"
      end
    else
      "Remix of #{blanked_name[:en]}"
    end
  end
end
