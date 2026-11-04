# frozen_string_literal: true

##
# A user's collection items that match a party's grid items by granblue_id,
# loaded for the party blueprint's viewer_collection and source_collection.
#
# Reads the party's already-loaded grid associations for the ids, then runs
# one WHERE IN query per kind.
module PartyCollectionMatches
  WEAPON_INCLUDES = [
    { weapon: %i[weapon_series weapon_series_variant] },
    :awakening, :weapon_key1, :weapon_key2, :weapon_key3, :weapon_key4,
    :ax_modifier1, :ax_modifier2, :befoulment_modifier,
    { collection_weapon_bullets: :bullet }
  ].freeze

  module_function

  ##
  # @param party [Party] a party with its characters, weapons and summons loaded
  # @param user [User] whose collection to search
  # @return [Hash{Symbol => ActiveRecord::Relation, Array}] characters, weapons
  #   and summons; an empty array for a kind the party has none of
  def for(party, user)
    character_ids = granblue_ids(party.characters, :character)
    weapon_ids = granblue_ids(party.weapons, :weapon)
    summon_ids = granblue_ids(party.summons, :summon)

    {
      characters: matching(character_ids) do
        user.collection_characters.joins(:character)
            .includes({ character: :character_series_records }, :awakening)
            .where(characters: { granblue_id: character_ids })
      end,
      weapons: matching(weapon_ids) do
        user.collection_weapons.joins(:weapon).includes(*WEAPON_INCLUDES).where(weapons: { granblue_id: weapon_ids })
      end,
      summons: matching(summon_ids) do
        user.collection_summons.joins(:summon).includes(summon: :summon_series).where(summons: { granblue_id: summon_ids })
      end
    }
  end

  def granblue_ids(rows, item)
    rows.filter_map { |row| row.public_send(item)&.granblue_id }.uniq
  end

  def matching(ids)
    ids.any? ? yield : []
  end
end
