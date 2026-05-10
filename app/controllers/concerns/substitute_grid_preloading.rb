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
  end
end
