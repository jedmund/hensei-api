# frozen_string_literal: true

##
# Orders a catalog relation by a requested sort key and direction, in the
# request's language. Each sort is declared as data, key => columns: the first
# column takes the requested direction, the rest are fixed tiebreakers, and id
# breaks any remaining tie. +:name+ stands for the language's name column.
#
# @example
#   CatalogSort::ITEMS.apply(Weapon.all, 'name', 'desc', 'ja')
#   # => ORDER BY name_jp DESC, id ASC
class CatalogSort
  # @param language [String] 'ja' or 'en'
  # @return [Symbol] the catalog column holding names in that language
  def self.name_column(language)
    language == 'ja' ? :name_jp : :name_en
  end

  # @param sorts [Hash{String => Array}] sort key => [column, *tiebreakers]
  # @param fallback [Proc] applied to the relation for an unknown sort key
  def initialize(sorts, fallback:)
    @sorts = sorts
    @fallback = fallback
  end

  # @param scope [ActiveRecord::Relation]
  # @param key [String] sort key
  # @param direction [String] 'desc' sorts descending; anything else ascending
  # @param language [String] 'ja' or 'en'
  # @return [ActiveRecord::Relation]
  def apply(scope, key, direction, language)
    column, *tiebreakers = @sorts[key]
    return @fallback.call(scope) unless column

    column = self.class.name_column(language) if column == :name
    scope.order({ column => direction == 'desc' ? :desc : :asc }, *tiebreakers, id: :asc)
  end

  # Characters, weapons and summons; an unknown key leaves the order alone
  ITEMS = new(
    { 'name' => [:name], 'element' => [:element], 'rarity' => [:rarity], 'last_updated' => [:latest_date] },
    fallback: :itself.to_proc
  )
end
