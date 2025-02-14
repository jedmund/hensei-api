# frozen_string_literal: true

module PartyQueryingConcern
  extend ActiveSupport::Concern
  include PartyConstants

  # Returns the common base query for Parties including all necessary associations.
  def build_common_base_query
    Party.includes(
      { raid: :group },
      :job,
      :user,
      :skill0,
      :skill1,
      :skill2,
      :skill3,
      :guidebook1,
      :guidebook2,
      :guidebook3,
      { characters: :character },
      { weapons: :weapon },
      { summons: :summon }
    )
  end

  # Uses PartyQueryBuilder to apply additional filters (includes, excludes, date ranges, etc.)
  def build_filtered_query(base_query)
    PartyQueryBuilder.new(base_query,
                          params: params,
                          current_user: current_user,
                          options: { apply_defaults: true }).build
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
        per_page: COLLECTION_PER_PAGE
      },
      current_user: current_user
    )
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
