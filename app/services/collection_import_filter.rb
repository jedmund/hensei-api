# frozen_string_literal: true

##
# The game inventory filter an extension sync was captured under, so reconciliation only
# deletes items inside that view.
#
# Current extension builds send game numbers as `element_ids` / `proficiency_ids`. Builds
# released before elements and proficiencies were renumbered to the game's send our old
# numbers as `elements` / `proficiencies`; those are converted here so an old build can't
# scope deletions to the wrong items. Drop the legacy keys once those builds are gone.
#
# @example
#   filter = CollectionImportFilter.from({ 'element_ids' => [1, 2] })
#   filter.elements # => [1, 2]
class CollectionImportFilter
  LEGACY_ELEMENTS = { 1 => 4, 2 => 1, 3 => 2, 4 => 3, 5 => 6, 6 => 5 }.freeze
  LEGACY_PROFICIENCIES = { 1 => 1, 2 => 2, 3 => 4, 4 => 3, 5 => 8, 6 => 5, 7 => 7, 8 => 9, 9 => 6, 10 => 10 }.freeze

  attr_reader :elements, :proficiencies

  # @param raw [Hash, nil] the filter param as sent by the client
  # @return [CollectionImportFilter, nil] nil when the client sent no usable filter
  def self.from(raw)
    return nil if raw.blank?

    raw = raw.to_h.with_indifferent_access
    filter = new(
      elements: ids(raw[:element_ids]) || legacy(raw[:elements], LEGACY_ELEMENTS),
      proficiencies: ids(raw[:proficiency_ids]) || legacy(raw[:proficiencies], LEGACY_PROFICIENCIES)
    )
    filter.empty? ? nil : filter
  end

  def self.ids(values)
    list = Array(values).filter_map { |v| Integer(v, exception: false) }
    list.presence
  end

  def self.legacy(values, map)
    ids(values)&.map { |v| map.fetch(v, v) }
  end

  private_class_method :ids, :legacy

  def initialize(elements: nil, proficiencies: nil)
    @elements = elements
    @proficiencies = proficiencies
  end

  def empty?
    elements.blank? && proficiencies.blank?
  end
end
