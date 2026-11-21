# frozen_string_literal: true

##
# Imports a user's Wonders from the game's `/item/memorial_list/1` response
# (an array of categories, each with an `item` list).
#
# - Upserts by item_id (our granblue_id). Unknown Wonders are skipped and
#   reported, never added to the catalogue.
# - Wonders missing from the payload are left alone: the game never takes
#   Wonders away, so a missing one was entered by hand.
# - active comes from set_flg; level and evolution are stored only for
#   leveled Wonders; possession and image only for scaling ones.
# - The bonus lines the game sent are kept in imported_bonuses and compared
#   with the computed bonuses by order and value (the names are localized). A
#   mismatch is logged and reported in warnings, and the row is still saved.
class WonderCollectionImport
  MAX_ITEMS = 500
  MAX_NAME_LENGTH = 100

  Result = Struct.new(:created, :updated, :skipped, :warnings, keyword_init: true) do
    def as_json(*)
      { success: true, created: created, updated: updated, skipped: skipped, warnings: warnings }
    end
  end

  class InvalidPayload < StandardError; end

  # @param user [User]
  # @param data [Array<Hash>] the raw response body (string keys)
  def initialize(user, data)
    @user = user
    @data = data
  end

  def call
    items = parse_items
    wonders = Wonder.includes(:level_bonuses, :evolution_caps)
                    .where(granblue_id: items.map { |item| item_id(item) }).index_by(&:granblue_id)
    existing = @user.collection_wonders.where(wonder_id: wonders.values.map(&:id)).index_by(&:wonder_id)
    result = Result.new(created: 0, updated: 0, skipped: [], warnings: [])

    CollectionWonder.transaction do
      items.each { |item| import_item(item, wonders[item_id(item)], existing, result) }
    end
    result
  end

  # The numeric value of a bonus line's detail, e.g. "+10%" or "＋10％" → 10
  def self.detail_value(detail)
    number = detail.to_s.unicode_normalize(:nfkc)[/[-+]?\d+(?:\.\d+)?/]
    number && BigDecimal(number)
  end

  private

  def parse_items
    raise InvalidPayload, 'data must be a list of categories' unless @data.is_a?(Array)

    items = @data.flat_map do |category|
      raise InvalidPayload, 'each category must be an object' unless category.is_a?(Hash)

      list = category['item'] || []
      raise InvalidPayload, 'each category item must be a list' unless list.is_a?(Array)

      list
    end
    raise InvalidPayload, "data can hold at most #{MAX_ITEMS} Wonders" if items.size > MAX_ITEMS
    raise InvalidPayload, 'each Wonder must be an object with an item_id' unless items.all? { |i| i.is_a?(Hash) && item_id(i).present? }

    items.uniq { |item| item_id(item) }
  end

  def item_id(item)
    item['item_id'].to_s
  end

  def import_item(item, wonder, existing, result)
    unless wonder
      result.skipped << skip_entry(item, 'unknown_wonder')
      Rails.logger.warn("[WonderCollectionImport] user=#{@user.id} unknown Wonder #{item_id(item)}")
      return
    end

    row = existing[wonder.id] || @user.collection_wonders.build(wonder: wonder)
    created = row.new_record?
    row.assign_attributes(attributes_for(item, wonder))

    if row.save
      created ? result.created += 1 : result.updated += 1
      check_bonuses(row, result)
    else
      result.skipped << skip_entry(item, 'invalid').merge(errors: row.errors.full_messages)
    end
  end

  def attributes_for(item, wonder)
    leveled = wonder.leveled?
    scaling = wonder.scaling?
    {
      active: item['set_flg'].to_s == '1',
      level: leveled ? integer(item['level']) : nil,
      evolution: leveled ? integer(item['evolution']) || 0 : nil,
      possession: scaling ? integer(item.dig('effective_acquired_bonus', 'current_bonus', 'possession')) : nil,
      image: scaling ? item['image'].to_s.presence : nil,
      imported_bonuses: imported_bonuses(item),
      synced_at: Time.current
    }
  end

  def integer(value)
    Integer(value.to_s, 10)
  rescue ArgumentError
    nil
  end

  # The bonus lines as sent: a list for leveled Wonders, Symbolum's
  # current_bonus object for scaling ones. Only the display fields are kept.
  def imported_bonuses(item)
    bonus = item['effective_acquired_bonus']
    case bonus
    when Array
      bonus.grep(Hash).map { |line| line.slice('name', 'detail', 'image').transform_values(&:to_s) }
    when Hash
      current = bonus['current_bonus']
      current.is_a?(Hash) ? current.slice('name', 'detail', 'value', 'possession', 'next_upgrade', 'is_max') : nil
    end
  end

  def check_bonuses(row, result)
    imported = imported_values(row.imported_bonuses)
    return if imported.nil?

    computed = row.bonuses.map { |bonus| BigDecimal(bonus[:value].to_s) }
    return if imported == computed

    Rails.logger.warn(
      "[WonderCollectionImport] user=#{@user.id} Wonder #{row.wonder.granblue_id} bonuses differ: " \
      "imported #{imported.map(&:to_s)} computed #{computed.map(&:to_s)}"
    )
    result.warnings << { granblue_id: row.wonder.granblue_id, reason: 'bonus_mismatch' }
  end

  def imported_values(imported)
    case imported
    when Array then imported.map { |line| self.class.detail_value(line['detail']) }
    when Hash then imported['value'].nil? ? nil : [self.class.detail_value(imported['value'])]
    end
  end

  def skip_entry(item, reason)
    { granblue_id: item_id(item), name: item['name'].to_s.truncate(MAX_NAME_LENGTH), reason: reason }
  end
end
