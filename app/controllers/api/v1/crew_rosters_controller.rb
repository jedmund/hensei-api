# frozen_string_literal: true

class Api::V1::CrewRostersController < Api::V1::ApiController
  include CrewAuthorizationConcern

  before_action :restrict_access
  before_action :set_crew
  before_action :set_roster, only: %i[show update destroy]

  def index
    rosters = @crew.crew_rosters.order(:element)
    render json: Api::V1::CrewRosterBlueprint.render(rosters, root: :crew_rosters)
  end

  def show
    # If the roster has items, also fetch ownership data
    result = { roster: Api::V1::CrewRosterBlueprint.render_as_hash(@roster, view: :full) }

    if @roster.items.present?
      character_ids = @roster.items.select { |i| i['type'] == 'Character' }.map { |i| i['id'] }
      weapon_ids = @roster.items.select { |i| i['type'] == 'Weapon' }.map { |i| i['id'] }
      summon_ids = @roster.items.select { |i| i['type'] == 'Summon' }.map { |i| i['id'] }

      result[:items] = enrich_items(character_ids, weapon_ids, summon_ids)
      result[:members] = fetch_roster_members(character_ids, weapon_ids, summon_ids)
    else
      result[:items] = []
      result[:members] = []
    end

    render json: result
  end

  def update
    authorize_crew_officer!

    @roster.update!(roster_params)
    render json: Api::V1::CrewRosterBlueprint.render(@roster, root: :crew_roster, view: :full)
  end

  def destroy
    authorize_crew_officer!

    @roster.destroy!
    head :no_content
  end

  private

  def set_crew
    @crew = current_user.crew
    render_not_found_response unless @crew
  end

  def set_roster
    @roster = @crew.crew_rosters.find(params[:id])
  end

  def roster_params
    params.permit(:name, items: [:id, :type])
  end

  def enrich_items(character_ids, weapon_ids, summon_ids)
    items = []

    if character_ids.present?
      Character.where(id: character_ids).each do |c|
        items << {
          id: c.id, type: 'Character', granblue_id: c.granblue_id, name: c.name_en,
          element: c.element, season: c.season,
          uncap: { flb: c.flb, transcendence: c.transcendence },
          special: c.special
        }
      end
    end

    if weapon_ids.present?
      Weapon.where(id: weapon_ids).each do |w|
        items << {
          id: w.id, type: 'Weapon', granblue_id: w.granblue_id, name: w.name_en,
          element: w.element,
          uncap: { flb: w.flb, ulb: w.ulb, transcendence: w.transcendence }
        }
      end
    end

    if summon_ids.present?
      Summon.where(id: summon_ids).each do |s|
        items << {
          id: s.id, type: 'Summon', granblue_id: s.granblue_id, name: s.name_en,
          element: s.element,
          uncap: { flb: s.flb, ulb: s.ulb, transcendence: s.transcendence }
        }
      end
    end

    # Preserve the original ordering from the roster
    item_order = @roster.items.map { |i| i['id'] }
    items.sort_by { |i| item_order.index(i[:id]) || items.length }
  end

  def fetch_roster_members(character_ids, weapon_ids, summon_ids)
    memberships = @crew.active_memberships.includes(:user)
    user_ids = memberships.map(&:user_id)

    # Batch-load all collection data in 3 queries (instead of 3 × N members)
    chars_by_user = if character_ids.present?
      CollectionCharacter.where(user_id: user_ids)
        .joins(:character)
        .where(characters: { id: character_ids })
        .includes(:character)
        .group_by(&:user_id)
    else
      {}
    end

    weapons_by_user = if weapon_ids.present?
      CollectionWeapon.where(user_id: user_ids)
        .joins(:weapon)
        .where(weapons: { id: weapon_ids })
        .includes(:weapon)
        .group_by(&:user_id)
    else
      {}
    end

    summons_by_user = if summon_ids.present?
      CollectionSummon.where(user_id: user_ids)
        .joins(:summon)
        .where(summons: { id: summon_ids })
        .includes(:summon)
        .group_by(&:user_id)
    else
      {}
    end

    memberships.map do |membership|
      user = membership.user
      {
        user_id: user.id,
        username: user.username,
        role: membership.role,
        characters: (chars_by_user[user.id] || []).map { |cc|
          c = cc.character
          {
            id: c.id,
            uncap_level: cc.uncap_level,
            transcendence_step: cc.transcendence_step,
            flb: c.flb,
            transcendence: c.transcendence,
            special: c.special
          }
        },
        weapons: (weapons_by_user[user.id] || []).map { |cw|
          w = cw.weapon
          {
            id: w.id,
            uncap_level: cw.uncap_level,
            transcendence_step: cw.transcendence_step,
            flb: w.flb,
            ulb: w.ulb,
            transcendence: w.transcendence
          }
        },
        summons: (summons_by_user[user.id] || []).map { |cs|
          s = cs.summon
          {
            id: s.id,
            uncap_level: cs.uncap_level,
            transcendence_step: cs.transcendence_step,
            flb: s.flb,
            ulb: s.ulb,
            transcendence: s.transcendence
          }
        }
      }
    end
  end
end
