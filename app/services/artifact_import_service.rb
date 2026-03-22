# frozen_string_literal: true

##
# Service for importing artifacts from game JSON data.
# Matches skills by name (EN or JP) and stores quality tier for later strength calculation.
#
# @example Import artifacts for a user
#   service = ArtifactImportService.new(user, game_data)
#   result = service.import
#   if result.success?
#     puts "Imported #{result.created_count} artifacts"
#   end
#
class ArtifactImportService
  Result = Struct.new(:success?, :created, :updated, :skipped, :errors, :reconciliation, keyword_init: true)

  # Game element values to our element enum values
  # Game: 1=Fire, 2=Water, 3=Earth, 4=Wind, 5=Light, 6=Dark
  # Ours: wind=1, fire=2, water=3, earth=4, dark=5, light=6
  ELEMENT_MAPPING = {
    '1' => 2,  # Fire
    '2' => 3,  # Water
    '3' => 4,  # Earth
    '4' => 1,  # Wind
    '5' => 6,  # Light
    '6' => 5   # Dark
  }.freeze

  # Game artifact 'kind' values to our proficiency enum values
  # Game: 1=Sabre, 2=Dagger, 3=Spear, 4=Axe, 5=Staff, 6=Gun, 7=Melee, 8=Bow, 9=Harp, 10=Katana
  # Ours: 1=Sabre, 2=Dagger, 3=Axe, 4=Spear, 5=Bow, 6=Staff, 7=Melee, 8=Harp, 9=Gun, 10=Katana
  PROFICIENCY_MAPPING = {
    '1' => 1,   # Sabre
    '2' => 2,   # Dagger
    '3' => 4,   # Spear
    '4' => 3,   # Axe
    '5' => 6,   # Staff
    '6' => 9,   # Gun
    '7' => 7,   # Melee
    '8' => 5,   # Bow
    '9' => 8,   # Harp
    '10' => 10  # Katana
  }.freeze

  def initialize(user, game_data, options = {})
    @user = user
    @game_data = game_data
    @update_existing = options[:update_existing] || false
    @is_full_inventory = options[:is_full_inventory] || false
    @reconcile_deletions = options[:reconcile_deletions] || false
    @filter = options[:filter] # { elements: [...], proficiencies: [...] }
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
  # @return [Array<CollectionArtifact>] Collection artifacts that would be deleted
  def preview_deletions
    items = extract_items
    return [] if items.empty?

    # Extract all game_ids from the import data
    # Artifacts use 'id' directly (not nested in 'param')
    game_ids = items.filter_map do |item|
      data = item.is_a?(Hash) ? item.with_indifferent_access : item
      data['id'].to_s if data['id'].present?
    end

    return [] if game_ids.empty?

    # Find collection artifacts with game_ids NOT in the import
    # Scoped to filter criteria if present
    scope = @user.collection_artifacts
                 .includes(:artifact)
                 .where.not(game_id: nil)
                 .where.not(game_id: game_ids)

    scope = apply_filter_scope(scope)
    scope
  end

  ##
  # Imports artifacts from game data.
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
        errors: ['No artifact items found in data'],
        reconciliation: nil
      )
    end

    # Preload artifacts and existing collection artifacts to avoid N+1 queries
    preload_artifacts(items)
    preload_existing_collection_artifacts(items)

    ActiveRecord::Base.transaction do
      items.each_with_index do |item, index|
        import_item(item, index)
      rescue StandardError => e
        @errors << { index: index, game_id: item['id'], error: e.message }
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

  def preload_artifacts(items)
    artifact_ids = items.map { |item| (item['artifact_id'] || item[:artifact_id]).to_s }.uniq
    artifacts = Artifact.where(granblue_id: artifact_ids).index_by(&:granblue_id)
    @artifacts_cache = artifacts
  end

  def preload_existing_collection_artifacts(items)
    game_ids = items.map { |item| (item['id'] || item[:id]).to_s }.uniq
    existing = @user.collection_artifacts.where(game_id: game_ids).index_by(&:game_id)
    @existing_cache = existing
  end

  def import_item(item, _index)
    # Handle both string and symbol keys from params
    data = item.is_a?(Hash) ? item.with_indifferent_access : item

    # Track this game_id as processed (for reconciliation)
    game_id = data['id']
    @processed_game_ids << game_id.to_s if game_id.present?

    artifact = find_artifact(data['artifact_id'])
    unless artifact
      @errors << { game_id: data['id'], artifact_id: data['artifact_id'], error: 'Artifact not found' }
      return
    end

    # Check for existing collection artifact with same game ID
    existing = @existing_cache[data['id'].to_s]

    if existing
      if @update_existing
        update_existing_artifact(existing, data, artifact)
      else
        @skipped << { game_id: data['id'], reason: 'Already exists' }
      end
      return
    end

    create_collection_artifact(data, artifact)
  end

  def find_artifact(artifact_id)
    @artifacts_cache[artifact_id.to_s]
  end

  def create_collection_artifact(item, artifact)
    attrs = build_collection_artifact_attrs(item, artifact)

    collection_artifact = @user.collection_artifacts.build(attrs)

    if collection_artifact.save
      @created << collection_artifact
    else
      @errors << {
        game_id: item['id'],
        artifact_id: item['artifact_id'],
        error: collection_artifact.errors.full_messages.join(', ')
      }
    end
  end

  def update_existing_artifact(existing, item, artifact)
    attrs = build_collection_artifact_attrs(item, artifact)

    if existing.update(attrs)
      @updated << existing
    else
      @errors << {
        game_id: item['id'],
        artifact_id: item['artifact_id'],
        error: existing.errors.full_messages.join(', ')
      }
    end
  end

  def build_collection_artifact_attrs(item, artifact)
    # Handle both string and symbol keys from params
    data = item.is_a?(Hash) ? item.with_indifferent_access : item

    # Extract Cygames scores
    score_info = data['score_info'] || {}

    # Update score_category on ArtifactSkill records if present
    update_skill_score_categories(data)

    {
      artifact: artifact,
      game_id: data['id'].to_s,
      element: map_element(data['attribute']),
      proficiency: artifact.quirk? ? map_proficiency(data['kind']) : nil,
      level: data['level'].to_i,
      skill1: parse_skill(data['skill1_info']),
      skill2: parse_skill(data['skill2_info']),
      skill3: parse_skill(data['skill3_info']),
      skill4: parse_skill(data['skill4_info']),
      attack_score: score_info['attack_score'],
      defense_score: score_info['defense_score'],
      special_score: score_info['special_score'],
      total_score: score_info['total_score'],
      raw_data: data
    }
  end

  def map_element(game_element)
    ELEMENT_MAPPING[game_element.to_s]
  end

  def map_proficiency(kind)
    PROFICIENCY_MAPPING[kind.to_s]
  end

  def update_skill_score_categories(data)
    (1..4).each do |slot|
      info = data["skill#{slot}_info"]
      next if info.blank?

      info = info.is_a?(Hash) ? info.with_indifferent_access : info
      category = info['score_category']
      next if category.blank? || category.to_s == ''

      name = info['name']
      skill = ArtifactSkill.find_by_game_name(name)
      next unless skill
      next if skill.score_category.present?

      skill.update_column(:score_category, category.to_i)
    end
  end

  def parse_skill(skill_info)
    return {} if skill_info.blank?

    # Handle both string and symbol keys from params
    info = skill_info.is_a?(Hash) ? skill_info.with_indifferent_access : skill_info

    name = info['name']
    quality = info['skill_quality'] || info['level'] || 1
    level = info['level'] || 1

    # Look up skill by game name (supports both EN and JP)
    skill = ArtifactSkill.find_by_game_name(name)
    return {} unless skill

    {
      'modifier' => skill.modifier,
      'quality' => quality.to_i,
      'level' => level.to_i
    }
  end

  ##
  # Reconciles deletions by removing collection artifacts not in the processed list.
  # Only called when @is_full_inventory and @reconcile_deletions are both true.
  # When a filter is active, only deletes items matching that filter.
  #
  # @return [Hash] Reconciliation result with deleted count and orphaned grid item IDs
  def reconcile_deletions
    # Find collection artifacts with game_ids NOT in our processed list
    # Scoped to filter criteria if present
    scope = @user.collection_artifacts
                 .where.not(game_id: nil)
                 .where.not(game_id: @processed_game_ids)

    scope = apply_filter_scope(scope)

    deleted_count = 0
    orphaned_grid_item_ids = []

    scope.find_each do |coll_artifact|
      # Collect IDs of grid items that will be orphaned
      grid_artifact_ids = GridArtifact.where(collection_artifact_id: coll_artifact.id).pluck(:id)
      orphaned_grid_item_ids.concat(grid_artifact_ids)

      # The before_destroy callback on CollectionArtifact will mark grid items as orphaned
      coll_artifact.destroy
      deleted_count += 1
    end

    {
      deleted: deleted_count,
      orphaned_grid_items: orphaned_grid_item_ids
    }
  end

  ##
  # Applies element and proficiency filters to a collection artifacts scope.
  # Used to scope deletion checks to only items matching the current game filter.
  #
  # @param scope [ActiveRecord::Relation] The collection artifacts relation to filter
  # @return [ActiveRecord::Relation] Filtered relation
  def apply_filter_scope(scope)
    return scope unless @filter.present?

    # Filter by elements if specified
    if @filter[:elements].present? || @filter['elements'].present?
      elements = @filter[:elements] || @filter['elements']
      scope = scope.where(element: elements)
    end

    # Filter by proficiencies if specified
    if @filter[:proficiencies].present? || @filter['proficiencies'].present?
      proficiencies = @filter[:proficiencies] || @filter['proficiencies']
      scope = scope.where(proficiency: proficiencies)
    end

    scope
  end
end
