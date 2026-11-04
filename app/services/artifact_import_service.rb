# frozen_string_literal: true

##
# Imports artifacts from the game's artifact list into the user's
# CollectionArtifact records. The shared flow is CollectionImport::Inventory;
# artifact items are flat ({ id:, artifact_id:, skill1_info:, ... }), and skills
# are matched by name (EN or JP), keeping the quality tier for later strength
# calculation.
#
# @example Import artifacts for a user
#   result = ArtifactImportService.new(user, game_data).import
#   result.created.size # => artifacts added
#
class ArtifactImportService < CollectionImport::Inventory
  collection_import :artifact, grid_model: GridArtifact

  private

  # Handles both string and symbol keys from params.
  def import_item(item)
    super(item.is_a?(Hash) ? item.with_indifferent_access : item)
  end

  # Preloads the artifacts and the user's copies, avoiding N+1 queries.
  def prepare(items)
    artifact_ids = items.map { |item| (item['artifact_id'] || item[:artifact_id]).to_s }.uniq
    @artifacts_cache = Artifact.where(granblue_id: artifact_ids).index_by(&:granblue_id)

    game_ids = items.map { |item| (item['id'] || item[:id]).to_s }.uniq
    @existing_cache = collection.where(game_id: game_ids).index_by(&:game_id)
  end

  def game_id(item)
    (item.is_a?(Hash) ? item.with_indifferent_access : item)['id']
  end

  def failed_game_id(item)
    item['id']
  end

  def find_catalog(item)
    @artifacts_cache[item['artifact_id'].to_s]
  end

  def owned_copy(item)
    @existing_cache[item['id'].to_s]
  end

  def item_ref(item, _catalog = nil)
    { game_id: item['id'], artifact_id: item['artifact_id'] }
  end

  def build_attrs(item, artifact)
    data = item.is_a?(Hash) ? item.with_indifferent_access : item
    score_info = data['score_info'] || {}
    update_skill_score_categories(data)

    {
      artifact: artifact,
      game_id: data['id'].to_s,
      element: game_number(data['attribute'], GranblueEnums::ELEMENTS),
      proficiency: artifact.quirk? ? game_number(data['kind'], GranblueEnums::PROFICIENCY) : nil,
      level: data['level'].to_i,
      skill1: parse_skill(data['skill1_info']),
      skill2: parse_skill(data['skill2_info']),
      skill3: parse_skill(data['skill3_info']),
      skill4: parse_skill(data['skill4_info']),
      attack_score: score_info['attack_score'],
      defense_score: score_info['defense_score'],
      special_score: score_info['special_score'],
      total_score: score_info['total_score']
    }
  end

  # The game's attribute and kind are our element and proficiency numbers.
  def game_number(value, enum)
    id = Integer(value.to_s, exception: false)
    id if id&.positive? && enum.value?(id)
  end

  # Fills in an ArtifactSkill's score category the first time an import sees it.
  def update_skill_score_categories(data)
    (1..4).each do |slot|
      info = data["skill#{slot}_info"]
      next if info.blank?

      info = info.with_indifferent_access if info.is_a?(Hash)
      category = info['score_category']
      next if category.blank?

      skill = ArtifactSkill.find_by_game_name(info['name'])
      next if skill.nil? || skill.score_category.present?

      skill.update_columns(score_category: category.to_i, updated_at: Time.current)
    end
  end

  def parse_skill(skill_info)
    return {} if skill_info.blank?

    info = skill_info.is_a?(Hash) ? skill_info.with_indifferent_access : skill_info
    skill = ArtifactSkill.find_by_game_name(info['name'])
    return {} unless skill

    {
      'modifier' => skill.modifier,
      'quality' => (info['skill_quality'] || info['level'] || 1).to_i,
      'level' => (info['level'] || 1).to_i
    }
  end

  def filter_scope(scope, filter)
    scope = scope.where(element: filter.elements) if filter.elements.present?
    scope = scope.where(proficiency: filter.proficiencies) if filter.proficiencies.present?
    scope
  end
end
