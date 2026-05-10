# frozen_string_literal: true

# Shared helper for hydrating the polymorphic substitute_grid records that
# hang off a substitution row.
#
# `includes(substitutions: :substitute_grid)` cannot carry nested preloads
# through the polymorphic association, so each substitute would otherwise
# fan out into its own per-record N+1 (character → series, weapon → keys,
# summon → series). Group the already-loaded substitutes by type and run a
# typed Preloader against each group using the per-grid
# `NESTED_BLUEPRINT_PRELOADS` constants.
#
# Also stamps an `owned` flag on each substitute so the API can tell the
# client which substitutes the current_user has in their collection — the
# substitute_grid's own `collection_*_id` is only set when the row was
# *created from* a Collection record, which the substitution flow never
# does. The client-visible "in collection" badge needs a per-user lookup.
module SubstituteGridPreloading
  extend ActiveSupport::Concern

  GRID_KLASSES = [GridCharacter, GridWeapon, GridSummon].freeze

  # Hydrate the substitute_grid records nested inside the given grids'
  # substitutions, in-place.
  #
  # @param grids [Enumerable<GridCharacter, GridWeapon, GridSummon>] grids
  #   whose `substitutions` association is already loaded.
  def preload_substitute_grids!(grids)
    substitutions = Array(grids).flat_map(&:substitutions)
    return if substitutions.empty?

    GRID_KLASSES.each do |klass|
      records = substitutions
                .select { |s| s.substitute_grid_type == klass.name }
                .filter_map(&:substitute_grid)
      next if records.empty?

      ActiveRecord::Associations::Preloader.new(
        records: records,
        associations: klass::NESTED_BLUEPRINT_PRELOADS
      ).call
    end

    stamp_substitute_ownership!(substitutions)
  end

  private

  # Sets the virtual `owned` attribute on each substitute_grid so the
  # blueprint can render whether current_user has the underlying entity in
  # their collection.
  def stamp_substitute_ownership!(substitutions)
    return unless current_user

    substitute_grids = substitutions.filter_map(&:substitute_grid)
    return if substitute_grids.empty?

    char_subs = substitute_grids.select { |s| s.is_a?(GridCharacter) }
    weapon_subs = substitute_grids.select { |s| s.is_a?(GridWeapon) }
    summon_subs = substitute_grids.select { |s| s.is_a?(GridSummon) }

    if char_subs.any?
      owned = CollectionCharacter.where(user_id: current_user.id,
                                        character_id: char_subs.map(&:character_id))
                                 .pluck(:character_id).to_set
      char_subs.each { |s| s.owned = owned.include?(s.character_id) }
    end

    if weapon_subs.any?
      owned = CollectionWeapon.where(user_id: current_user.id,
                                     weapon_id: weapon_subs.map(&:weapon_id))
                              .pluck(:weapon_id).to_set
      weapon_subs.each { |s| s.owned = owned.include?(s.weapon_id) }
    end

    return if summon_subs.empty?

    owned = CollectionSummon.where(user_id: current_user.id,
                                   summon_id: summon_subs.map(&:summon_id))
                            .pluck(:summon_id).to_set
    summon_subs.each { |s| s.owned = owned.include?(s.summon_id) }
  end
end
