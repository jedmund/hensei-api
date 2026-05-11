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

  # (collection_class, fk-on-grid-row) for each grid type. The blueprint reads
  # `owned` from the grid row, so the fk we look up is the one on the row.
  OWNERSHIP_BY_GRID = {
    GridCharacter => [CollectionCharacter, :character_id],
    GridWeapon    => [CollectionWeapon, :weapon_id],
    GridSummon    => [CollectionSummon, :summon_id]
  }.freeze

  # Sets the virtual `owned` attribute on each substitute_grid so the
  # blueprint can render whether current_user has the underlying entity in
  # their collection.
  def stamp_substitute_ownership!(substitutions)
    return unless current_user

    substitute_grids = substitutions.filter_map(&:substitute_grid)
    return if substitute_grids.empty?

    substitute_grids.group_by(&:class).each do |klass, grids|
      collection_class, fk = OWNERSHIP_BY_GRID[klass]
      next unless collection_class

      owned = collection_class.where(user_id: current_user.id,
                                     fk => grids.map(&fk))
                              .pluck(fk).to_set
      grids.each { |g| g.owned = owned.include?(g.send(fk)) }
    end
  end
end
