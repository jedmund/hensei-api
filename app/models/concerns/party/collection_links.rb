# frozen_string_literal: true

##
# Links from a party's grid items to their owner's collection items, and the
# rule that a remix only keeps links into the remixer's own collection.
module Party::CollectionLinks
  extend ActiveSupport::Concern

  ##
  # Drops collection links on an unsaved remix copy that don't point into
  # the remixer's own collection, so a remix only keeps sync with the
  # remixer's items. Each link is checked against its own item's owner.
  # Works on the in-memory grid items amoeba built; call before saving.
  #
  # @param user [User, nil] the user the copy will belong to.
  # @return [void]
  def keep_only_collection_links_of!(user)
    characters = all_characters.to_a
    weapons = all_weapons.to_a
    summons = all_summons.to_a
    artifacts = characters.filter_map(&:grid_artifact)

    kept_character_ids = owned_collection_ids(CollectionCharacter, characters, :collection_character_id, user)
    kept_weapon_ids = owned_collection_ids(CollectionWeapon, weapons, :collection_weapon_id, user)
    kept_summon_ids = owned_collection_ids(CollectionSummon, summons, :collection_summon_id, user)
    kept_artifact_ids = owned_collection_ids(CollectionArtifact, artifacts, :collection_artifact_id, user)

    characters.each do |gc|
      gc.collection_character_id = nil unless kept_character_ids.include?(gc.collection_character_id)
    end
    [[weapons, :collection_weapon_id, kept_weapon_ids],
     [summons, :collection_summon_id, kept_summon_ids],
     [artifacts, :collection_artifact_id, kept_artifact_ids]].each do |rows, column, kept|
      rows.each do |row|
        next if row[column].nil? || kept.include?(row[column])

        row[column] = nil
        row.orphaned = false
      end
    end

    self.collection_source_user_id = nil unless user && collection_source_user_id == user.id
  end

  private

  # Ids among the rows' links that point at the user's own collection items.
  def owned_collection_ids(model, rows, column, user)
    ids = rows.filter_map { |row| row[column] }.uniq
    return Set.new if ids.empty? || user.nil?

    model.where(id: ids, user_id: user.id).pluck(:id).to_set
  end
end
