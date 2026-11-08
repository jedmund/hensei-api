# frozen_string_literal: true

##
# Imports weapons from the game's weapon list into the user's CollectionWeapon
# records. The shared flow is CollectionImport::Inventory; this class finds the
# weapon (element-changeable weapons included) and maps uncap, transcendence,
# awakening, AX skills and befoulment.
#
# @example Import weapons for a user
#   result = WeaponImportService.new(user, game_data, update_existing: true).import
#   result.created.size # => weapons added
#
class WeaponImportService < CollectionImport::Inventory
  include CollectionImport::GameItems

  collection_import :weapon, grid_model: GridWeapon

  # Game awakening form to our slug mapping
  AWAKENING_FORM_MAPPING = {
    1 => 'weapon-atk',     # Attack
    2 => 'weapon-def',     # Defense
    3 => 'weapon-special', # Special
    4 => 'weapon-ca',      # C.A.
    5 => 'weapon-skill',   # Skill DMG
    6 => 'weapon-heal'     # Healing
  }.freeze

  def initialize(user, game_data, options = {})
    super
    @awakening_cache = {}
    @augment_parser = Granblue::AugmentSkillParser.new(log_tag: 'WeaponImportService')
  end

  private

  # Element-changeable weapons arrive under element-variant ids that differ from
  # the base granblue_id; those are found through element_variant_ids.
  def catalog_model = Weapon

  # An element variant's game id is stored on its base weapon
  def find_catalog_fallback(granblue_id)
    Weapon.where('EXISTS (SELECT 1 FROM jsonb_each_text(element_variant_ids) AS kv WHERE kv.value = ?)',
                 granblue_id).first
  end

  # The element of the variant the game id names, or nil for a weapon without variants.
  def variant_element(weapon, variant_id)
    return nil if weapon.element_variant_ids.blank?

    weapon.element_variant_ids.find { |_k, v| v == variant_id }&.first&.to_i
  end

  def build_attrs(item, weapon)
    param = game_params(item)
    attrs = {
      weapon: weapon,
      game_id: game_id_attr(item),
      **game_uncap(param['evolution'], param['phase']),
      element: variant_element(weapon, granblue_id(item).to_s)
    }

    awakening_attrs = parse_awakening(param['arousal'])
    attrs.merge!(awakening_attrs) if awakening_attrs

    # Befoulment and exorcism level for Odious weapons, AX skills otherwise
    attrs.merge!(@augment_parser.attributes(param))
  end

  ##
  # Parses awakening data from game format.
  #
  # @param arousal [Hash] The game's arousal (awakening) data
  # @return [Hash, nil] Awakening attributes or nil if no awakening
  def parse_awakening(arousal)
    return nil if arousal.blank? || arousal['is_arousal_weapon'] != true
    return nil if arousal['level'].blank?

    awakening = find_awakening_by_form(arousal['form'].to_i)
    return nil unless awakening

    { awakening_id: awakening.id, awakening_level: arousal['level'].to_i.clamp(1, 20) }
  end

  def find_awakening_by_form(form)
    slug = AWAKENING_FORM_MAPPING[form]
    return nil unless slug

    @awakening_cache[slug] ||= Awakening.find_by(slug: slug, object_type: 'Weapon')
  end

  # Element: the copy's element first (element-changeable weapons), else the
  # weapon's. Proficiency: the weapon's.
  def filter_scope(scope, filter)
    if filter.elements.present?
      scope = scope.joins(:weapon).where(
        'collection_weapons.element IN (?) OR (collection_weapons.element IS NULL AND weapons.element IN (?))',
        filter.elements, filter.elements
      )
    end
    scope = scope.joins(:weapon).where(weapons: { proficiency: filter.proficiencies }) if filter.proficiencies.present?
    scope
  end
end
