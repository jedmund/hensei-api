# frozen_string_literal: true

##
# Service for importing summons from game JSON data.
# Parses the game's summon inventory data and creates CollectionSummon records.
#
# @example Import summons for a user
#   service = SummonImportService.new(user, game_data)
#   result = service.import
#   if result.success?
#     puts "Imported #{result.created.size} summons"
#   end
#
class SummonImportService
  Result = Struct.new(:success?, :created, :updated, :skipped, :errors, :reconciliation, keyword_init: true)

  def initialize(user, game_data, options = {})
    @user = user
    @game_data = game_data
    @update_existing = options[:update_existing] || false
    @is_full_inventory = options[:is_full_inventory] || false
    @reconcile_deletions = options[:reconcile_deletions] || false
    @filter = options[:filter] # { elements: [...] }
    @conflict_resolutions = options[:conflict_resolutions] || {}
    @created = []
    @updated = []
    @skipped = []
    @errors = []
    @processed_game_ids = []
  end

  ##
  # Previews what would be deleted in a sync operation.
  # Does not modify any data, just returns items that would be removed.
  # When a filter is active, only considers items matching that filter.
  #
  # @return [Array<CollectionSummon>] Collection summons that would be deleted
  def preview_deletions
    items = extract_items
    return [] if items.empty?

    # Extract all game_ids from the import data
    game_ids = items.filter_map do |item|
      param = item['param'] || {}
      param['id'].to_s if param['id'].present?
    end

    return [] if game_ids.empty?

    # Find collection summons with game_ids NOT in the import
    # Scoped to filter criteria if present
    scope = @user.collection_summons
                 .includes(:summon)
                 .where.not(game_id: nil)
                 .where.not(game_id: game_ids)

    scope = apply_filter_scope(scope)
    scope
  end

  ##
  # Imports summons from game data.
  #
  # @return [Result] Import result with counts and errors
  def import
    items = extract_items
    if items.empty?
      return Result.new(
        success?: false,
        created: [],
        updated: [],
        skipped: [],
        errors: ['No summon items found in data'],
        reconciliation: nil
      )
    end

    ActiveRecord::Base.transaction do
      items.each_with_index do |item, index|
        import_item(item, index)
      rescue StandardError => e
        @errors << { index: index, game_id: item.dig('param', 'id'), error: e.message }
      end
    end

    # Handle deletion reconciliation if requested
    reconciliation_result = nil
    if @reconcile_deletions && @is_full_inventory && @processed_game_ids.any?
      reconciliation_result = reconcile_deletions
    end

    Result.new(
      success?: @errors.empty?,
      created: @created,
      updated: @updated,
      skipped: @skipped,
      errors: @errors,
      reconciliation: reconciliation_result
    )
  end

  private

  def extract_items
    return @game_data if @game_data.is_a?(Array)
    return @game_data['list'] if @game_data.is_a?(Hash) && @game_data['list'].is_a?(Array)

    []
  end

  def import_item(item, _index)
    param = item['param'] || {}
    master = item['master'] || {}

    # The summon's granblue_id can be in param.image_id or master.id
    # image_id may have a suffix like "_04" for transcended summons, so strip it
    image_id = param['image_id'].to_s.split('_').first if param['image_id'].present?
    granblue_id = image_id || master['id']
    game_id = param['id']

    # Track this game_id as processed (for reconciliation)
    @processed_game_ids << game_id.to_s if game_id.present?

    summon = find_summon(granblue_id)
    unless summon
      @errors << { game_id: game_id, granblue_id: granblue_id, error: 'Summon not found' }
      return
    end

    # Check for existing collection summon with same game ID
    existing = @user.collection_summons.find_by(game_id: game_id.to_s)
    found_via_conflict = false

    # If no match by game_id, check for conflict resolutions (null game_id records)
    if !existing && game_id.present? && @conflict_resolutions.present?
      resolution = @conflict_resolutions[game_id.to_s]
      if resolution == 'import'
        existing = @user.collection_summons.find_by(summon_id: summon.id, game_id: nil)
        found_via_conflict = true
      elsif resolution == 'skip'
        @skipped << { game_id: game_id, reason: 'Skipped by user' }
        return
      end
    end

    if existing
      if @update_existing || found_via_conflict
        update_existing_summon(existing, item, summon)
      else
        @skipped << { game_id: game_id, reason: 'Already exists' }
      end
      return
    end

    create_collection_summon(item, summon)
  end

  def find_summon(granblue_id)
    id_str = granblue_id.to_s
    Summon.find_by(granblue_id: id_str) ||
      Summon.find_by(granblue_id: SummonIdMapping.resolve(id_str))
  end

  def create_collection_summon(item, summon)
    attrs = build_collection_summon_attrs(item, summon)

    collection_summon = @user.collection_summons.build(attrs)

    if collection_summon.save
      @created << collection_summon
    else
      @errors << {
        game_id: item.dig('param', 'id'),
        granblue_id: summon.granblue_id,
        error: collection_summon.errors.full_messages.join(', ')
      }
    end
  end

  def update_existing_summon(existing, item, summon)
    attrs = build_collection_summon_attrs(item, summon)

    if existing.update(attrs)
      @updated << existing
    else
      @errors << {
        game_id: item.dig('param', 'id'),
        granblue_id: summon.granblue_id,
        error: existing.errors.full_messages.join(', ')
      }
    end
  end

  def build_collection_summon_attrs(item, summon)
    param = item['param'] || {}

    uncap = parse_uncap_level(param['evolution'])
    transcendence = parse_transcendence_step(param['phase'])

    # Transcended summons have uncap_level 6 (beyond the normal 0-5 range)
    uncap = 6 if transcendence > 0 && uncap >= 5

    {
      summon: summon,
      game_id: param['id'].present? ? param['id'].to_s : nil,
      uncap_level: uncap,
      transcendence_step: transcendence
    }
  end

  def parse_uncap_level(evolution)
    value = evolution.to_i
    value.clamp(0, 5)
  end

  def parse_transcendence_step(phase)
    value = phase.to_i
    value.clamp(0, 10)
  end

  ##
  # Reconciles deletions by removing collection summons not in the processed list.
  # Only called when @is_full_inventory and @reconcile_deletions are both true.
  # When a filter is active, only deletes items matching that filter.
  #
  # @return [Hash] Reconciliation result with deleted count and orphaned grid item IDs
  def reconcile_deletions
    # Find collection summons with game_ids NOT in our processed list
    # Scoped to filter criteria if present
    scope = @user.collection_summons
                 .where.not(game_id: nil)
                 .where.not(game_id: @processed_game_ids)

    scope = apply_filter_scope(scope)

    deleted_count = 0
    orphaned_grid_item_ids = []

    scope.find_each do |coll_summon|
      # Collect IDs of grid items that will be orphaned
      grid_summon_ids = GridSummon.where(collection_summon_id: coll_summon.id).pluck(:id)
      orphaned_grid_item_ids.concat(grid_summon_ids)

      # The before_destroy callback on CollectionSummon will mark grid items as orphaned
      coll_summon.destroy
      deleted_count += 1
    end

    {
      deleted: deleted_count,
      orphaned_grid_items: orphaned_grid_item_ids
    }
  end

  ##
  # Applies element filter to a collection summons scope.
  # Used to scope deletion checks to only items matching the current game filter.
  #
  # @param scope [ActiveRecord::Relation] The collection summons relation to filter
  # @return [ActiveRecord::Relation] Filtered relation
  def apply_filter_scope(scope)
    return scope unless @filter.present?

    # Element: always join through summon (no element on collection_summons)
    if @filter[:elements].present? || @filter['elements'].present?
      elements = @filter[:elements] || @filter['elements']
      scope = scope.joins(:summon).where(summons: { element: elements })
    end

    # Summons don't have proficiency - ignore if present in filter
    scope
  end
end
