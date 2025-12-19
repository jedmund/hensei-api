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
  Result = Struct.new(:success?, :created, :updated, :skipped, :errors, keyword_init: true)

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

  def initialize(user, game_data, options = {})
    @user = user
    @game_data = game_data
    @update_existing = options[:update_existing] || false
    @created = []
    @updated = []
    @skipped = []
    @errors = []
  end

  ##
  # Imports artifacts from game data.
  #
  # @return [Result] Import result with counts and errors
  def import
    items = extract_items
    if items.empty?
      return Result.new(success?: false, created: [], updated: [], skipped: [], errors: ['No artifact items found in data'])
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

    Result.new(
      success?: @errors.empty?,
      created: @created,
      updated: @updated,
      skipped: @skipped,
      errors: @errors
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

    {
      artifact: artifact,
      game_id: data['id'].to_s,
      element: map_element(data['attribute']),
      proficiency: artifact.quirk? ? map_proficiency(data['kind']) : nil,
      level: data['level'].to_i,
      skill1: parse_skill(data['skill1_info']),
      skill2: parse_skill(data['skill2_info']),
      skill3: parse_skill(data['skill3_info']),
      skill4: parse_skill(data['skill4_info'])
    }
  end

  def map_element(game_element)
    ELEMENT_MAPPING[game_element.to_s]
  end

  def map_proficiency(kind)
    # Game 'kind' field maps directly to proficiency enum (1-10)
    kind.to_i
  end

  def parse_skill(skill_info)
    return {} if skill_info.blank?

    # Handle both string and symbol keys from params
    info = skill_info.is_a?(Hash) ? skill_info.with_indifferent_access : skill_info

    name = info['name']
    quality = info['skill_quality'] || info['level'] || 1
    level = info['level'] || 1

    # Look up skill by name (supports both EN and JP)
    skill = ArtifactSkill.find_by_name(name)
    return {} unless skill

    {
      'modifier' => skill.modifier,
      'quality' => quality.to_i,
      'level' => level.to_i
    }
  end
end
