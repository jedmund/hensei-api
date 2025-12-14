# frozen_string_literal: true

##
# Service for importing artifacts from game JSON data.
# Parses the game's skill_id format and converts to our (group, modifier) format.
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

  # Mapping from game skill base ID (skill_id / 10) to [group, modifier]
  # Built from analyzing game data samples and verified against artifact_skills.json
  GAME_SKILL_MAPPING = {
    # === GROUP I (Lines 1-2) ===
    1001 => [1, 1],   # ATK
    2001 => [1, 2],   # HP
    3001 => [1, 6],   # Critical Hit Rate
    3002 => [1, 3],   # C.A. DMG
    3003 => [1, 4],   # Skill DMG
    3004 => [1, 13],  # Debuff Success Rate
    3005 => [1, 7],   # Double Attack Rate
    3006 => [1, 8],   # Triple Attack Rate
    3007 => [1, 9],   # DEF
    3008 => [1, 14],  # Debuff Resistance
    3009 => [1, 11],  # Dodge Rate
    3010 => [1, 12],  # Healing
    3011 => [1, 5],   # Elemental ATK
    3012 => [1, 10],  # Superior Element Reduction

    # === GROUP II (Line 3) ===
    3013 => [2, 1],   # N.A. DMG Cap
    3014 => [2, 2],   # Skill DMG Cap
    3015 => [2, 3],   # C.A. DMG Cap
    3016 => [2, 9],   # Supplemental N.A. DMG
    3017 => [2, 10],  # Supplemental Skill DMG
    3018 => [2, 11],  # Supplemental C.A. DMG
    3019 => [2, 4],   # Special C.A. DMG Cap
    3020 => [2, 6],   # N.A. DMG cap boost tradeoff
    3021 => [2, 18],  # Turn-Based DMG Reduction
    3022 => [2, 17],  # Regeneration
    3023 => [2, 14],  # Amplify DMG at 100% HP
    3024 => [2, 13],  # Boost TA at 50%+ HP
    3025 => [2, 16],  # DMG reduction when at or below 50% HP
    3026 => [2, 5],   # Boost DMG cap for critical hits
    3027 => [2, 15],  # Max HP boost for a 70% hit to DEF
    3028 => [2, 12],  # Chain DMG Amplify
    3029 => [2, 7],   # Skill DMG cap boost tradeoff
    3030 => [2, 8],   # C.A. DMG cap boost tradeoff
    4000 => [2, 19],  # Chance to remove 1 debuff before attacking
    4001 => [2, 20],  # Chance to cancel incoming dispels

    # === GROUP III (Line 4) ===
    3031 => [3, 28],  # Boost item drop rate
    3032 => [3, 27],  # Boost EXP earned
    5001 => [3, 2],   # At battle start: Gain x random buff(s)
    5002 => [3, 8],   # Upon using a debuff skill: Amplify foe's DMG taken
    5003 => [3, 9],   # Upon using a healing skill: Ally bonus
    5004 => [3, 12],  # Cut linked skill cooldowns
    5005 => [3, 10],  # Gain 1% DMG Cap Up (Stackable)
    5006 => [3, 11],  # After using a skill with a cooldown of 10+ turns
    5007 => [3, 22],  # Gain Supplemental Skill DMG (Stackable)
    5008 => [3, 13],  # Gain Supplemental DMG based on charge bar spent
    5009 => [3, 20],  # Gain Flurry (3-hit)
    5010 => [3, 21],  # Plain DMG based on HP lost
    5011 => [3, 23],  # Upon single attacks: Gain random buff
    5012 => [3, 25],  # When foe has 3 or fewer debuffs: Armored
    5013 => [3, 6],   # When foe HP at 50% or lower: Restore HP
    5014 => [3, 26],  # When a sub ally: random debuff to foes
    5015 => [3, 19],  # Gain 20% Bonus DMG after being targeted
    5016 => [3, 14],  # At end of turn if didn't attack: Gain buff
    5017 => [3, 24],  # Upon using potion: Boost FC bar
    5018 => [3, 3],   # Start with 20% HP consumed / Cap Up
    5019 => [3, 4],   # When knocked out: All allies gain buffs
    5020 => [3, 5],   # When switching to main ally: Amplify DMG
    5021 => [3, 1],   # At battle start: Gain DMG Mitigation
    5022 => [3, 18],  # Chance to gain Flurry (6-hit)
    5023 => [3, 17],  # At battle start and every 5 turns: Shield
    5024 => [3, 16],  # Chance of turn progressing by 5
    5025 => [3, 7],   # Upon first-slot skill: Cut CD
    5026 => [3, 15],  # Chance to remove all buffs from foe
    5029 => [3, 29]   # May find earrings
  }.freeze

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

    skill_id = info['skill_id']
    quality = info['skill_quality'] || info['level']
    level = info['level'] || 1

    group, modifier = decode_skill_id(skill_id)
    return {} unless group && modifier

    # Get the strength value from ArtifactSkill
    strength = calculate_strength(group, modifier, quality.to_i)

    {
      'modifier' => modifier,
      'strength' => strength,
      'level' => level.to_i
    }
  end

  ##
  # Decodes a game skill_id to [group, modifier].
  # skill_id format: {base_id}{quality} where last digit is quality (1-5)
  #
  # @param skill_id [Integer] The game's skill ID
  # @return [Array<Integer, Integer>, nil] [group, modifier] or nil if unknown
  def decode_skill_id(skill_id)
    base_id = skill_id.to_i / 10
    GAME_SKILL_MAPPING[base_id]
  end

  ##
  # Calculates the strength value based on quality tier.
  # Quality 1-5 maps to base_values[0-4] in ArtifactSkill.
  #
  # @param group [Integer] Skill group (1, 2, or 3)
  # @param modifier [Integer] Skill modifier within group
  # @param quality [Integer] Quality tier (1-5)
  # @return [Float, Integer, nil] The strength value
  def calculate_strength(group, modifier, quality)
    skill = ArtifactSkill.find_skill(group, modifier)
    return nil unless skill

    base_values = skill.base_values
    return nil if base_values.nil? || !base_values.is_a?(Array) || base_values.empty?

    # Quality 1-5 maps to index 0-4
    index = (quality - 1).clamp(0, base_values.size - 1)
    base_values[index]
  end
end
