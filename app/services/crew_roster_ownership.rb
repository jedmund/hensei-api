# frozen_string_literal: true

##
# What a crew roster shows: its characters, weapons and summons with their
# uncap data, in roster order, and which of them each active member owns.
# Members whose collections the viewer can't see are listed with no copies.
#
# @example
#   ownership = CrewRosterOwnership.new(roster, crew: crew, viewer: current_user)
#   ownership.items   # => [{ id:, type: 'Weapon', granblue_id:, name:, element:, uncap: {...} }, ...]
#   ownership.members # => [{ user_id:, username:, role:, characters: [...], weapons: [...], summons: [...] }, ...]
class CrewRosterOwnership
  # Roster item type => [catalog model, collection model, collection association]
  SOURCES = {
    'Character' => [Character, CollectionCharacter, :character],
    'Weapon' => [Weapon, CollectionWeapon, :weapon],
    'Summon' => [Summon, CollectionSummon, :summon]
  }.freeze

  # @param roster [CrewRoster]
  # @param crew [Crew] the roster's crew, whose active members are listed
  # @param viewer [User] whose access to each member's collection applies
  def initialize(roster, crew:, viewer:)
    @roster = roster
    @crew = crew
    @viewer = viewer
  end

  # @return [Array<Hash>] the roster's items with their catalog details
  def items
    items = SOURCES.flat_map do |type, (model, _, _)|
      ids = item_ids(type)
      ids.present? ? model.where(id: ids).find_each.map { |record| item(type, record) } : []
    end

    # Preserve the original ordering from the roster
    item_order = @roster.items.pluck('id')
    items.sort_by { |i| item_order.index(i[:id]) || items.length }
  end

  # @return [Array<Hash>] each active member with their copies of the items
  def members
    memberships = @crew.active_memberships.includes(:user)
    # Respect each member's collection privacy; private collections stay empty.
    user_ids = memberships.select { |m| m.user.collection_viewable_by?(@viewer) }.map(&:user_id)
    # One query per item type, for every member at once
    owned = SOURCES.keys.index_with { |type| copies_by_user(type, user_ids) }

    memberships.map do |membership|
      user = membership.user
      {
        user_id: user.id,
        username: user.username,
        role: membership.role,
        characters: copies(owned['Character'][user.id], :character),
        weapons: copies(owned['Weapon'][user.id], :weapon),
        summons: copies(owned['Summon'][user.id], :summon)
      }
    end
  end

  private

  def item_ids(type)
    @roster.items.select { |i| i['type'] == type }.pluck('id')
  end

  def item(type, record)
    details = { id: record.id, type: type, granblue_id: record.granblue_id, name: record.name_en,
                element: record.element }
    details[:season] = record.season if type == 'Character'
    details[:uncap] = uncap(record)
    details[:special] = record.special if type == 'Character'
    details
  end

  def uncap(record)
    { flb: record.flb, ulb: record.ulb, transcendence: record.transcendence }
  end

  def copies_by_user(type, user_ids)
    ids = item_ids(type)
    return {} if ids.blank?

    _, collection, association = SOURCES[type]
    table = collection.reflect_on_association(association).klass.table_name
    collection.where(user_id: user_ids)
              .joins(association)
              .where(table => { id: ids })
              .includes(association)
              .group_by(&:user_id)
  end

  def copies(collection_items, association)
    (collection_items || []).map do |copy|
      record = copy.public_send(association)
      owned = { id: record.id, uncap_level: copy.uncap_level, transcendence_step: copy.transcendence_step,
                **uncap(record) }
      owned[:special] = record.special if association == :character
      owned
    end
  end
end
