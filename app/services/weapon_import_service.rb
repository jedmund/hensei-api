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
  Result = Struct.new(:success?, :created, :updated, :skipped, :errors, keyword_init: true)

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
    @created = []
    @updated = []
    @skipped = []
    @errors = []
    @awakening_cache = {}
  end

  ##
  # Imports weapons from game data.
  #
  # @return [Result] Import result with counts and errors
  def import
    items = extract_items
    return Result.new(success?: false, created: [], updated: [], skipped: [], errors: ['No weapon items found in data']) if items.empty?

    ActiveRecord::Base.transaction do
      items.each_with_index do |item, index|
        import_item(item, index)
      rescue StandardError => e
        @errors << { index: index, game_id: item.dig('param', 'id'), error: e.message }
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

  def import_item(item, _index)
    param = item['param'] || {}
    master = item['master'] || {}

    # The weapon's granblue_id can be in param.image_id or master.id
    granblue_id = param['image_id'] || master['id']
    game_id = param['id']

    weapon = find_weapon(granblue_id)
    unless weapon
      @errors << { game_id: game_id, granblue_id: granblue_id, error: 'Weapon not found' }
      return
    end

    # Check for existing collection weapon with same game ID
    existing = @user.collection_weapons.find_by(game_id: game_id.to_s)

    if existing
      if @update_existing
        update_existing_weapon(existing, item, weapon)
      else
        @skipped << { game_id: game_id, reason: 'Already exists' }
      end
      return
    end

    create_collection_weapon(item, weapon)
  end

  def find_weapon(granblue_id)
    Weapon.find_by(granblue_id: granblue_id.to_s)
  end

  def create_collection_weapon(item, weapon)
    attrs = build_collection_weapon_attrs(item, weapon)

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

  def update_existing_weapon(existing, item, weapon)
    attrs = build_collection_weapon_attrs(item, weapon)

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

  def build_collection_weapon_attrs(item, weapon)
    param = item['param'] || {}

    attrs = {
      weapon: weapon,
      game_id: param['id'].to_s,
      uncap_level: parse_uncap_level(param['evolution']),
      transcendence_step: parse_transcendence_step(param['phase'])
    }

    # Parse awakening if present
    awakening_attrs = parse_awakening(param['arousal'])
    attrs.merge!(awakening_attrs) if awakening_attrs

    # Parse AX skills if present
    ax_attrs = parse_ax_skills(param['augment_skill_info'])
    attrs.merge!(ax_attrs) if ax_attrs

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
      ax1 = parse_single_ax_skill(skills[0])
      if ax1
        attrs[:ax_modifier1] = ax1[:modifier]
        attrs[:ax_strength1] = ax1[:strength]
      end
    end

    # Second AX skill
    if skills[1].is_a?(Hash)
      ax2 = parse_single_ax_skill(skills[1])
      if ax2
        attrs[:ax_modifier2] = ax2[:modifier]
        attrs[:ax_strength2] = ax2[:strength]
      end
    end

    attrs.empty? ? nil : attrs
  end

  ##
  # Parses a single AX skill from game data.
  #
  # @param skill [Hash] Single AX skill data with skill_id and effect_value
  # @return [Hash, nil] { modifier:, strength: } or nil
  def parse_single_ax_skill(skill)
    return nil unless skill['skill_id'].present?

    # The skill_id maps to our AX modifier
    modifier = skill['skill_id'].to_i

    # Parse strength from effect_value (may be "3" or "1_3" format)
    # or from show_value (may be "3%" format)
    strength = parse_ax_strength(skill['effect_value'], skill['show_value'])

    return nil unless strength

    { modifier: modifier, strength: strength }
  end

  def parse_ax_strength(effect_value, show_value)
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
end
