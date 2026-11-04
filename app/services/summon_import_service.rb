# frozen_string_literal: true

##
# Imports summons from the game's summon list into the user's CollectionSummon
# records. The shared flow is CollectionImport::Inventory; this class finds the
# summon and maps uncap and transcendence.
#
# @example Import summons for a user
#   result = SummonImportService.new(user, game_data).import
#   result.created.size # => summons added
#
class SummonImportService < CollectionImport::Inventory
  include CollectionImport::GameItems

  collection_import :summon, grid_model: GridSummon

  private

  def find_catalog(item)
    id = granblue_id(item).to_s
    Summon.find_by(granblue_id: id) || Summon.find_by(granblue_id: SummonIdMapping.resolve(id))
  end

  def build_attrs(item, summon)
    param = game_params(item)
    { summon: summon, game_id: game_id_attr(item), **game_uncap(param['evolution'], param['phase']) }
  end

  # Element through the summon; summons have no proficiency.
  def filter_scope(scope, filter)
    return scope if filter.elements.blank?

    scope.joins(:summon).where(summons: { element: filter.elements })
  end
end
