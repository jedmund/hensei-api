# frozen_string_literal: true

##
# Job search: row, proficiency and feature filters, text search and sort
# (see CatalogSearchQuery). Unsorted jobs list by row, then in-row order.
#
# The proficiency filter matches the first slot within the other filters, or
# the second slot on its own: +(query AND row AND proficiency1) OR
# proficiency2+. A text search still limits both, as it joins its rank. The
# feature flags apply to both.
class JobSearchQuery < CatalogSearchQuery
  SORT = CatalogSort::JOBS
  TRUE_VALUES = [true, 'true'].freeze
  FLAGS = { 'masterLevel' => :master_level, 'ultimateMastery' => :ultimate_mastery, 'accessory' => :accessory }.freeze

  def call
    scope = searched(Job.all)
    scope = scope.where(row: filter_value('row')) if filter_value('row').present?
    scope = by_proficiency(scope, integers(filter_value('proficiency'))) if filter_value('proficiency').present?
    scope = FLAGS.reduce(scope) do |result, (param, column)|
      TRUE_VALUES.include?(filter_value(param)) ? result.where(column => true) : result
    end
    sorted(scope)
  end

  private

  def by_proficiency(scope, values)
    scope.where(proficiency1: values).or(Job.where(proficiency2: values))
  end

  def default_order(scope)
    scope.order(:row, :order)
  end
end
