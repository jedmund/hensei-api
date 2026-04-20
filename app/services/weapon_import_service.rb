# frozen_string_literal: true

##
# Service for importing weapons from game JSON data.
# Parses the game's weapon inventory data and creates CollectionWeapon records.
#
# @example Import weapons for a user
#   service = WeaponImportService.new(user, game_data)
#   result = service.import
#   if result.success?
#     puts "Imported #{result.created.size} weapons"
#   end
#
class WeaponImportService
  Result = Struct.new(:success?, :created, :updated, :skipped, :errors, :reconciliation, keyword_init: true)

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
    @user = user
    @game_data = game_data
    @update_existing = options[:update_existing] || false
    @is_full_inventory = options[:is_full_inventory] || false
    @reconcile_deletions = options[:reconcile_deletions] || false
    @filter = options[:filter] # { elements: [...], proficiencies: [...] }
    @conflict_resolutions = options[:conflict_resolutions] || {}
    @created = []
    @updated = []
    @skipped = []
    @errors = []
    @awakening_cache = {}
    @modifier_cache = {}
    @processed_game_ids = []
  end

  ##
  # Previews what would be deleted in a sync operation.
  # Does not modify any data, just returns items that would be removed.
  # When a filter is active, only considers items matching that filter.
  #
  # @return [Array<CollectionWeapon>] Collection weapons that would be deleted
  def preview_deletions
    items = extract_items
    return [] if items.empty?

    # Extract all game_ids from the import data
    game_ids = items.filter_map do |item|
      param = item['param'] || {}
      param['id'].to_s if param['id'].present?
    end

    return [] if game_ids.empty?

    # Find collection weapons with game_ids NOT in the import
    # Scoped to filter criteria if present
    scope = @user.collection_weapons
                 .includes(:weapon)
                 .where.not(game_id: nil)
                 .where.not(game_id: game_ids)

    scope = apply_filter_scope(scope)
    scope
  end

  ##
  # Imports weapons from game data.
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
        errors: ['No weapon items found in data'],
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

  ##
  # Dry-run: returns the diff that `import` (with update_existing: true) would apply
  # to each already-owned CollectionWeapon. Non-owned weapons are skipped.
  #
  # @return [Array<Hash>] one entry per changed record: { game_id:, granblue_id:, changes: [...] }
  def preview_updates
    items = extract_items
    return [] if items.empty?

    updates = []

    items.each do |item|
      param = item['param'] || {}
      master = item['master'] || {}

      game_id = param['id']
      next unless game_id.present?

      image_id = param['image_id'].to_s.split('_').first if param['image_id'].present?
      granblue_id = image_id || master['id']
      next unless granblue_id.present?

      weapon, resolved_element = find_weapon(granblue_id)
      next unless weapon

      existing = @user.collection_weapons.find_by(game_id: game_id.to_s)
      next unless existing

      attrs = build_collection_weapon_attrs(item, weapon, resolved_element)
      existing.assign_attributes(attrs)
      next if existing.changes.empty?

      updates << {
        game_id: game_id.to_s,
        granblue_id: weapon.granblue_id,
        changes: CollectionImport::ChangeFormatter.format(existing.changes)
      }
    end

    updates
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

    # The weapon's granblue_id can be in param.image_id or master.id
    # image_id may have a suffix like "_03" for Dark Opus weapons, so strip it
    image_id = param['image_id'].to_s.split('_').first if param['image_id'].present?
    granblue_id = image_id || master['id']
    game_id = param['id']

    # Track this game_id as processed (for reconciliation)
    @processed_game_ids << game_id.to_s if game_id.present?

    weapon, resolved_element = find_weapon(granblue_id)
    unless weapon
      @errors << { game_id: game_id, granblue_id: granblue_id, error: 'Weapon not found' }
      return
    end

    # Check for existing collection weapon with same game ID
    existing = @user.collection_weapons.find_by(game_id: game_id.to_s)
    found_via_conflict = false

    # If no match by game_id, check for conflict resolutions (null game_id records)
    if !existing && game_id.present? && @conflict_resolutions.present?
      resolution = @conflict_resolutions[game_id.to_s]
      if resolution == 'import'
        existing = @user.collection_weapons.find_by(weapon_id: weapon.id, game_id: nil)
        found_via_conflict = true
      elsif resolution == 'skip'
        @skipped << { game_id: game_id, reason: 'Skipped by user' }
        return
      end
    end

    if existing
      if @update_existing || found_via_conflict
        update_existing_weapon(existing, item, weapon, resolved_element)
      else
        @skipped << { game_id: game_id, reason: 'Already exists' }
      end
      return
    end

    create_collection_weapon(item, weapon, resolved_element)
  end

  # Finds a Weapon record for the given granblue_id.
  # For element-changeable weapons, the game sends element-variant IDs that differ
  # from the base granblue_id stored in our DB. We resolve these via element_variant_ids JSONB.
  #
  # @param granblue_id [String] the game's weapon ID (may be a variant ID)
  # @return [Array<Weapon, Integer>] the weapon and resolved element, or [nil, nil]
  def find_weapon(granblue_id)
    id_str = granblue_id.to_s

    # Direct match (works for non-element-changeable weapons and base variants)
    weapon = Weapon.find_by(granblue_id: id_str)
    if weapon
      # For element-changeable weapons, the base granblue_id may also be a variant ID
      element = resolve_element_from_variants(weapon, id_str)
      return [weapon, element]
    end

    # Reverse-lookup via element_variant_ids JSONB
    weapon = Weapon.where(
      "EXISTS (SELECT 1 FROM jsonb_each_text(element_variant_ids) AS kv WHERE kv.value = ?)",
      id_str
    ).first
    return [nil, nil] unless weapon

    element = resolve_element_from_variants(weapon, id_str)
    [weapon, element]
  end

  def resolve_element_from_variants(weapon, variant_id)
    return nil unless weapon.element_variant_ids.present?

    weapon.element_variant_ids.find { |_k, v| v == variant_id }&.first&.to_i
  end

  def create_collection_weapon(item, weapon, resolved_element = nil)
    attrs = build_collection_weapon_attrs(item, weapon, resolved_element)

    collection_weapon = @user.collection_weapons.build(attrs)

    if collection_weapon.save
      @created << collection_weapon
    else
      @errors << {
        game_id: item.dig('param', 'id'),
        granblue_id: weapon.granblue_id,
        error: collection_weapon.errors.full_messages.join(', ')
      }
    end
  end

  def update_existing_weapon(existing, item, weapon, resolved_element = nil)
    attrs = build_collection_weapon_attrs(item, weapon, resolved_element)

    if existing.update(attrs)
      @updated << existing
    else
      @errors << {
        game_id: item.dig('param', 'id'),
        granblue_id: weapon.granblue_id,
        error: existing.errors.full_messages.join(', ')
      }
    end
  end

  def build_collection_weapon_attrs(item, weapon, resolved_element = nil)
    param = item['param'] || {}

    uncap = parse_uncap_level(param['evolution'])
    transcendence = parse_transcendence_step(param['phase'])

    # Transcended weapons have uncap_level 6 (beyond the normal 0-5 range)
    uncap = 6 if transcendence > 0 && uncap >= 5

    attrs = {
      weapon: weapon,
      game_id: param['id'].present? ? param['id'].to_s : nil,
      uncap_level: uncap,
      transcendence_step: transcendence,
      element: resolved_element
    }

    # Parse awakening if present
    awakening_attrs = parse_awakening(param['arousal'])
    attrs.merge!(awakening_attrs) if awakening_attrs

    # Check if this is an Odiant (befoulment) weapon
    odiant = param['odiant']
    if odiant && odiant['is_odiant_weapon'] == true
      # Parse befoulment from augment_skill_info
      befoulment_attrs = parse_befoulment(param['augment_skill_info'])
      attrs.merge!(befoulment_attrs) if befoulment_attrs
      attrs[:exorcism_level] = odiant['exorcision_level'].to_i.clamp(0, 5)
    else
      # Regular weapon - parse AX skills
      ax_attrs = parse_ax_skills(param['augment_skill_info'])
      attrs.merge!(ax_attrs) if ax_attrs
    end

    attrs
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
  # Parses awakening data from game format.
  # Game arousal data contains level and form info.
  #
  # @param arousal [Hash] The game's arousal (awakening) data
  # @return [Hash, nil] Awakening attributes or nil if no awakening
  def parse_awakening(arousal)
    return nil if arousal.blank? || arousal['is_arousal_weapon'] != true
    return nil if arousal['level'].blank?

    form = arousal['form'].to_i
    awakening = find_awakening_by_form(form)
    return nil unless awakening

    {
      awakening_id: awakening.id,
      awakening_level: arousal['level'].to_i.clamp(1, 20)
    }
  end

  def find_awakening_by_form(form)
    slug = AWAKENING_FORM_MAPPING[form]
    return nil unless slug

    @awakening_cache[slug] ||= Awakening.find_by(slug: slug, object_type: 'Weapon')
  end

  ##
  # Parses AX skill data from game format.
  # Game augment_skill_info is an array of skill arrays.
  #
  # @param augment_skill_info [Array] The game's AX skill data
  # @return [Hash, nil] AX skill attributes or nil if no AX skills
  def parse_ax_skills(augment_skill_info)
    return nil if augment_skill_info.blank? || !augment_skill_info.is_a?(Array)

    # First entry in augment_skill_info is an array of skills
    skills = augment_skill_info.first
    return nil if skills.blank? || !skills.is_a?(Array)

    attrs = {}

    # First AX skill
    if skills[0].is_a?(Hash)
      ax1 = parse_single_augment_skill(skills[0])
      if ax1
        attrs[:ax_modifier1_id] = ax1[:modifier_id]
        attrs[:ax_strength1] = ax1[:strength]
      end
    end

    # Second AX skill
    if skills[1].is_a?(Hash)
      ax2 = parse_single_augment_skill(skills[1])
      if ax2
        attrs[:ax_modifier2_id] = ax2[:modifier_id]
        attrs[:ax_strength2] = ax2[:strength]
      end
    end

    attrs.empty? ? nil : attrs
  end

  ##
  # Parses befoulment data from game format.
  # Odiant weapons have a single befoulment in augment_skill_info.
  #
  # @param augment_skill_info [Array] The game's augment skill data
  # @return [Hash, nil] Befoulment attributes or nil if no befoulment
  def parse_befoulment(augment_skill_info)
    return nil if augment_skill_info.blank? || !augment_skill_info.is_a?(Array)

    skills = augment_skill_info.first
    return nil if skills.blank? || !skills.is_a?(Array)

    skill = skills.first
    return nil unless skill.is_a?(Hash)

    result = parse_single_augment_skill(skill)
    return nil unless result

    {
      befoulment_modifier_id: result[:modifier_id],
      befoulment_strength: result[:strength]
    }
  end

  ##
  # Parses a single augment skill (AX or befoulment) from game data.
  #
  # @param skill [Hash] Single skill data with skill_id and effect_value
  # @return [Hash, nil] { modifier_id:, strength: } or nil
  def parse_single_augment_skill(skill)
    return nil unless skill['skill_id'].present?

    game_skill_id = skill['skill_id'].to_i
    modifier = find_modifier_by_game_skill_id(game_skill_id)

    unless modifier
      # Log unknown skill ID with icon for discovery
      Rails.logger.warn(
        "[WeaponImportService] Unknown augment skill_id=#{game_skill_id} " \
        "icon=#{skill['augment_skill_icon_image']}"
      )
      return nil
    end

    strength = parse_augment_strength(skill['effect_value'], skill['show_value'])
    return nil unless strength

    { modifier_id: modifier.id, strength: strength }
  end

  def find_modifier_by_game_skill_id(game_skill_id)
    @modifier_cache[game_skill_id] ||= WeaponStatModifier.find_by(game_skill_id: game_skill_id)
  end

  def parse_augment_strength(effect_value, show_value)
    # Try effect_value first
    if effect_value.present?
      # Handle "1_3" format (seems to be "tier_value")
      if effect_value.to_s.include?('_')
        return effect_value.to_s.split('_').last.to_f
      end
      return effect_value.to_f if effect_value.to_s.match?(/\A[\d.]+\z/)
    end

    # Try show_value (e.g., "3%")
    if show_value.present?
      return show_value.to_s.gsub('%', '').to_f
    end

    nil
  end

  ##
  # Reconciles deletions by removing collection weapons not in the processed list.
  # Only called when @is_full_inventory and @reconcile_deletions are both true.
  # When a filter is active, only deletes items matching that filter.
  #
  # @return [Hash] Reconciliation result with deleted count and orphaned grid item IDs
  def reconcile_deletions
    # Find collection weapons with game_ids NOT in our processed list
    # Scoped to filter criteria if present
    scope = @user.collection_weapons
                 .where.not(game_id: nil)
                 .where.not(game_id: @processed_game_ids)

    scope = apply_filter_scope(scope)

    deleted_count = 0
    orphaned_grid_item_ids = []

    scope.find_each do |coll_weapon|
      # Collect IDs of grid items that will be orphaned
      grid_weapon_ids = GridWeapon.where(collection_weapon_id: coll_weapon.id).pluck(:id)
      orphaned_grid_item_ids.concat(grid_weapon_ids)

      # The before_destroy callback on CollectionWeapon will mark grid items as orphaned
      coll_weapon.destroy
      deleted_count += 1
    end

    {
      deleted: deleted_count,
      orphaned_grid_items: orphaned_grid_item_ids
    }
  end

  ##
  # Applies element and proficiency filters to a collection weapons scope.
  # Used to scope deletion checks to only items matching the current game filter.
  #
  # @param scope [ActiveRecord::Relation] The collection weapons relation to filter
  # @return [ActiveRecord::Relation] Filtered relation
  def apply_filter_scope(scope)
    return scope unless @filter.present?

    # Element: check collection_weapon.element first (for element-changeable weapons),
    # fall back to weapon.element if nil
    if @filter[:elements].present? || @filter['elements'].present?
      elements = @filter[:elements] || @filter['elements']
      scope = scope.joins(:weapon).where(
        'collection_weapons.element IN (?) OR (collection_weapons.element IS NULL AND weapons.element IN (?))',
        elements, elements
      )
    end

    # Proficiency: join through weapon
    if @filter[:proficiencies].present? || @filter['proficiencies'].present?
      proficiencies = @filter[:proficiencies] || @filter['proficiencies']
      scope = scope.joins(:weapon).where(weapons: { proficiency: proficiencies })
    end

    scope
  end
end
