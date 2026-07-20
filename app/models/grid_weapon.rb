# frozen_string_literal: true

##
# Model representing a grid weapon within a party.
#
# This model associates a weapon with a party and manages validations for weapon compatibility,
# conflict detection, and attribute adjustments such as determining if a weapon is mainhand.
#
# @!attribute [r] weapon
#   @return [Weapon] the associated weapon.
# @!attribute [r] party
#   @return [Party] the party to which the grid weapon belongs.
# @!attribute [r] weapon_key1
#   @return [WeaponKey, nil] the primary weapon key, if assigned.
# @!attribute [r] weapon_key2
#   @return [WeaponKey, nil] the secondary weapon key, if assigned.
# @!attribute [r] weapon_key3
#   @return [WeaponKey, nil] the tertiary weapon key, if assigned.
# @!attribute [r] weapon_key4
#   @return [WeaponKey, nil] the quaternary weapon key, if assigned.
# @!attribute [r] awakening
#   @return [Awakening, nil] the associated awakening, if any.
class GridWeapon < ApplicationRecord
  include WeaponCapabilityResolution
  include AxSkillValidation

  # Allowed extra positions (9, 10, 11 are the "extra" grid slots)
  EXTRA_POSITIONS = [9, 10, 11].freeze

  belongs_to :weapon, foreign_key: :weapon_id, primary_key: :id

  belongs_to :party,
             inverse_of: :weapons
  validates_presence_of :party

  has_many :substitutions, as: :grid, dependent: :destroy
  has_many :substitute_of, class_name: 'Substitution', as: :substitute_grid, dependent: :destroy

  belongs_to :weapon_key1, class_name: 'WeaponKey', foreign_key: :weapon_key1_id, optional: true
  belongs_to :weapon_key2, class_name: 'WeaponKey', foreign_key: :weapon_key2_id, optional: true
  belongs_to :weapon_key3, class_name: 'WeaponKey', foreign_key: :weapon_key3_id, optional: true
  belongs_to :weapon_key4, class_name: 'WeaponKey', foreign_key: :weapon_key4_id, optional: true

  belongs_to :awakening, optional: true
  belongs_to :collection_weapon, optional: true

  belongs_to :ax_modifier1, class_name: 'WeaponStatModifier', optional: true
  belongs_to :ax_modifier2, class_name: 'WeaponStatModifier', optional: true
  belongs_to :befoulment_modifier, class_name: 'WeaponStatModifier', optional: true

  has_many :grid_weapon_bullets, dependent: :destroy
  has_many :bullets, through: :grid_weapon_bullets

  # Associations the nested blueprint walks. Reused by controllers and the
  # polymorphic substitute-grid preloader so a single source of truth keeps
  # them in sync as the blueprint evolves.
  NESTED_BLUEPRINT_PRELOADS = [
    :awakening,
    :weapon_key1, :weapon_key2, :weapon_key3,
    :ax_modifier1, :ax_modifier2, :befoulment_modifier,
    { grid_weapon_bullets: :bullet },
    { collection_weapon: :collection_weapon_bullets },
    { weapon: [:awakenings, :weapon_series, :weapon_series_variant,
               :recruited_character, :base_weapon, :forge_chain_weapons,
               { weapon_skills: { weapon_skill_versions: :skill } }] }
  ].freeze

  # Orphan status scopes
  scope :orphaned, -> { where(orphaned: true) }
  scope :not_orphaned, -> { where(orphaned: false) }

  # Validate that uncap_level is present and numeric, transcendence_step is optional but must be numeric if present.
  validates :uncap_level, presence: true, numericality: { only_integer: true }
  validates :transcendence_step, numericality: { only_integer: true }, allow_nil: true
  validates :befoulment_permeation, inclusion: { in: 1..6 }, allow_nil: true
  validates :skill_level, inclusion: { in: 1..25 }, allow_nil: true

  validate :validate_transcendence_step
  validate :compatible_with_position, unless: :is_substitute?
  validate :compatible_with_job_proficiency, on: :create, unless: :is_substitute?
  validate :no_conflicts, on: :create, unless: :is_substitute?
  validate :no_duplicate_weapon_keys
  validate :no_duplicate_weapon_key_slots

  before_save :assign_mainhand
  before_validation :set_default_uncap_level, on: :create
  before_validation :set_default_exorcism_level, on: :create

  after_create :increment_party_counter, unless: :is_substitute?
  after_destroy :decrement_party_counter, unless: :is_substitute?

  # Virtual attribute set by the controller for substitute renders. See
  # GridCharacter#owned for the full rationale.
  attr_accessor :owned

  ##### Amoeba configuration
  amoeba do
    nullify :ax_modifier1_id
    nullify :ax_modifier2_id
    nullify :ax_strength1
    nullify :ax_strength2
    nullify :befoulment_modifier_id
    nullify :befoulment_strength
    nullify :befoulment_permeation
    nullify :exorcism_level
    nullify :skill_level
    nullify :description
  end

  ##
  # Returns the blueprint for rendering the grid weapon.
  #
  # @return [GridWeaponBlueprint] the blueprint class for grid weapons.
  def blueprint
    GridWeaponBlueprint
  end

  ##
  # Syncs customizations from the linked collection weapon.
  #
  # @return [Boolean] true if sync was performed, false if no collection link
  # Maps camelCase keys emitted by #out_of_sync_fields to the underlying
  # column names. Bullets live in a join table and use the special `bullets.N`
  # keys, handled separately from this map.
  SYNC_FIELD_MAP = {
    'uncapLevel' => %i[uncap_level],
    'transcendenceStep' => %i[transcendence_step],
    'element' => %i[element],
    'weaponKey1' => %i[weapon_key1_id],
    'weaponKey2' => %i[weapon_key2_id],
    'weaponKey3' => %i[weapon_key3_id],
    'weaponKey4' => %i[weapon_key4_id],
    'ax.0' => %i[ax_modifier1_id ax_strength1],
    'ax.1' => %i[ax_modifier2_id ax_strength2],
    'befoulmentModifier' => %i[befoulment_modifier_id],
    'befoulmentStrength' => %i[befoulment_strength],
    'befoulmentPermeation' => %i[befoulment_permeation],
    'exorcismLevel' => %i[exorcism_level],
    'skillLevel' => %i[skill_level],
    'awakeningId' => %i[awakening_id],
    'awakeningLevel' => %i[awakening_level]
  }.freeze

  ALL_SYNC_COLUMNS = SYNC_FIELD_MAP.values.flatten.uniq.freeze

  def sync_from_collection!(fields: nil)
    return false unless collection_weapon.present?

    columns = sync_columns_for(fields)
    bullet_positions = sync_bullet_positions_for(fields)

    update!(columns.index_with { |col| collection_weapon.public_send(col) }) if columns.any?

    if bullet_positions == :all
      grid_weapon_bullets.destroy_all
      collection_weapon.collection_weapon_bullets.each do |cwb|
        grid_weapon_bullets.create!(bullet_id: cwb.bullet_id, position: cwb.position)
      end
    elsif bullet_positions.is_a?(Array)
      bullet_positions.each { |position| pull_bullet_position!(position) }
    end

    true
  end

  ##
  # Syncs customizations from this grid weapon to the linked collection weapon.
  #
  # @param fields [Array<String>, nil] optional list of camelCase keys to sync
  # @return [Boolean] true if sync was performed, false if no collection link
  def sync_to_collection!(fields: nil)
    return false unless collection_weapon.present?

    columns = sync_columns_for(fields)
    bullet_positions = sync_bullet_positions_for(fields)

    collection_weapon.update!(columns.index_with { |col| public_send(col) }) if columns.any?

    if bullet_positions == :all
      collection_weapon.collection_weapon_bullets.destroy_all
      grid_weapon_bullets.each do |gwb|
        collection_weapon.collection_weapon_bullets.create!(bullet_id: gwb.bullet_id, position: gwb.position)
      end
    elsif bullet_positions.is_a?(Array)
      bullet_positions.each { |position| push_bullet_position!(position) }
    end

    true
  end

  ##
  # Marks this grid weapon as orphaned and clears its collection link.
  #
  # @return [Boolean] true if the update succeeded
  def mark_orphaned!
    update!(orphaned: true, collection_weapon_id: nil)
  end

  ##
  # Checks if grid weapon is out of sync with collection.
  #
  # @return [Boolean] true if any customization differs from collection
  def out_of_sync?
    out_of_sync_fields.any?
  end

  ##
  # Returns the list of fields that differ from the linked collection weapon.
  # Uses camelCase keys for value fields (`uncapLevel`), `weaponKey{N}` for the
  # 1-based weapon key slots, and dotted keys (`ax.0`/`ax.1`, `bullets.N` by
  # position) for fields the UI renders as individual rows.
  def out_of_sync_fields
    return [] unless collection_weapon.present?

    fields = []
    fields << 'uncapLevel' if uncap_level != collection_weapon.uncap_level
    fields << 'transcendenceStep' if transcendence_step != collection_weapon.transcendence_step
    fields << 'element' if element != collection_weapon.element
    fields << 'weaponKey1' if weapon_key1_id != collection_weapon.weapon_key1_id
    fields << 'weaponKey2' if weapon_key2_id != collection_weapon.weapon_key2_id
    fields << 'weaponKey3' if weapon_key3_id != collection_weapon.weapon_key3_id
    fields << 'weaponKey4' if weapon_key4_id != collection_weapon.weapon_key4_id
    if ax_modifier1_id != collection_weapon.ax_modifier1_id || ax_strength1 != collection_weapon.ax_strength1
      fields << 'ax.0'
    end
    if ax_modifier2_id != collection_weapon.ax_modifier2_id || ax_strength2 != collection_weapon.ax_strength2
      fields << 'ax.1'
    end
    fields << 'befoulmentModifier' if befoulment_modifier_id != collection_weapon.befoulment_modifier_id
    fields << 'befoulmentStrength' if befoulment_strength != collection_weapon.befoulment_strength
    fields << 'befoulmentPermeation' if befoulment_permeation != collection_weapon.befoulment_permeation
    fields << 'exorcismLevel' if exorcism_level != collection_weapon.exorcism_level
    fields << 'skillLevel' if skill_level != collection_weapon.skill_level
    fields << 'awakeningId' if awakening_id != collection_weapon.awakening_id
    fields << 'awakeningLevel' if awakening_level != collection_weapon.awakening_level
    fields.concat(out_of_sync_bullet_positions.map { |position| "bullets.#{position}" })
    fields
  end

  ##
  # Returns an array of assigned weapon keys.
  #
  # This method returns an array containing weapon_key1, weapon_key2, and weapon_key3,
  # omitting any nil values.
  #
  # @return [Array<WeaponKey>] the non-nil weapon keys.
  def weapon_keys
    [weapon_key1, weapon_key2, weapon_key3].compact
  end

  ##
  # Returns conflicting grid weapons within a given party.
  #
  # Checks if the associated weapon is present, responds to a :limit method, and is limited.
  # It then iterates over the party's grid weapons and selects those that conflict with this one,
  # based on series matching or specific conditions related to opus or draconic status.
  #
  # @param party [Party] the party in which to check for conflicts.
  # @return [ActiveRecord::Relation<GridWeapon>] an array of conflicting grid weapons (empty if none are found).
  def conflicts(party)
    return [] unless weapon.present? && weapon.respond_to?(:limit) && weapon.limit

    party.weapons.select do |party_weapon|
      # Skip if the record is not persisted.
      next false unless party_weapon.id.present?

      id_match = weapon.id == party_weapon.id
      series_match = weapon.weapon_series_id.present? &&
                     weapon.weapon_series_id == party_weapon.weapon.weapon_series_id
      both_opus_or_draconic = weapon.opus_or_draconic? && party_weapon.weapon.opus_or_draconic?
      both_draconic = weapon.draconic_or_providence? && party_weapon.weapon.draconic_or_providence?

      (series_match || both_opus_or_draconic || both_draconic) && !id_match
    end
  end

  private

  def sync_columns_for(fields)
    return ALL_SYNC_COLUMNS if fields.blank?

    fields.flat_map { |key| SYNC_FIELD_MAP[key] || [] }.uniq
  end

  # Returns :all (every bullet position) when fields is blank, an Array of
  # positions when the caller scoped to specific `bullets.N` keys, or [] when
  # the caller targeted some other section and bullets should stay put.
  def sync_bullet_positions_for(fields)
    return :all if fields.blank?

    fields.filter_map do |key|
      next unless key.start_with?('bullets.')

      Integer(key.split('.', 2).last, 10)
    rescue ArgumentError, TypeError
      nil
    end
  end

  def pull_bullet_position!(position)
    collection_bullet = collection_weapon.collection_weapon_bullets.find_by(position: position)
    grid_bullet = grid_weapon_bullets.find_by(position: position)

    if collection_bullet.nil?
      grid_bullet&.destroy!
    elsif grid_bullet.nil?
      grid_weapon_bullets.create!(bullet_id: collection_bullet.bullet_id, position: position)
    else
      grid_bullet.update!(bullet_id: collection_bullet.bullet_id)
    end
  end

  def push_bullet_position!(position)
    grid_bullet = grid_weapon_bullets.find_by(position: position)
    collection_bullet = collection_weapon.collection_weapon_bullets.find_by(position: position)

    if grid_bullet.nil?
      collection_bullet&.destroy!
    elsif collection_bullet.nil?
      collection_weapon.collection_weapon_bullets.create!(bullet_id: grid_bullet.bullet_id, position: position)
    else
      collection_bullet.update!(bullet_id: grid_bullet.bullet_id)
    end
  end

  ##
  # Validates the transcendence step of the weapon.
  #
  # @return [void]
  def validate_transcendence_step
    return if transcendence_step.nil?

    if weapon&.transcendence
      errors.add(:transcendence_step, 'transcendence step too high') if transcendence_step > 5
      errors.add(:transcendence_step, 'transcendence step too low') if transcendence_step.negative?
    elsif transcendence_step.positive?
      errors.add(:transcendence_step, 'weapon has no transcendence')
    end
  end

  ##
  # Validates whether the grid weapon is compatible with the desired position.
  #
  # For positions 9, 10, or 11 (considered extra positions), the weapon's series must have the `extra` flag set.
  # If the weapon is in an extra position but does not match an allowed series, an error is added.
  #
  # @return [void]
  def compatible_with_position
    return unless weapon.present?

    if EXTRA_POSITIONS.include?(position.to_i)
      unless weapon.extra
        errors.add(:series, 'must be compatible with position')
        return
      end

      if weapon.extra_prerequisite.present? && uncap_level < weapon.extra_prerequisite
        errors.add(:uncap_level, 'must meet extra prerequisite')
      end
    end
  end

  ##
  # Validates that the assigned weapon keys are compatible with the weapon.
  #
  # Iterates over each non-nil weapon key and checks compatibility using the weapon's
  # `compatible_with_key?` method. An error is added for any key that is not compatible.
  #
  # @return [void]
  def compatible_with_key
    weapon_keys.each do |key|
      errors.add(:weapon_keys, 'must be compatible with weapon') unless weapon.compatible_with_key?(key)
    end
  end

  def no_duplicate_weapon_keys
    key_ids = [weapon_key1_id, weapon_key2_id, weapon_key3_id, weapon_key4_id].compact
    if key_ids.length != key_ids.uniq.length
      errors.add(:weapon_keys, 'cannot have duplicate keys')
    end
  end

  def no_duplicate_weapon_key_slots
    slots = [weapon_key1, weapon_key2, weapon_key3, weapon_key4].compact.map(&:slot)
    if slots.length != slots.uniq.length
      errors.add(:weapon_keys, 'cannot have multiple keys for the same slot')
    end
  end

  ##
  # Validates that there are no conflicting grid weapons in the party.
  #
  # Checks if the current grid weapon conflicts with any other grid weapons within the party.
  # If conflicting weapons are found, an error is added.
  #
  # @return [void]
  def no_conflicts
    conflicting = conflicts(party)
    errors.add(:series, 'must not conflict with existing weapons') if conflicting.any?
  end

  ##
  # Validates that mainhand weapon proficiency matches the job's proficiency.
  #
  # For position -1 (mainhand), the weapon's proficiency must match either
  # the party's job proficiency1 or proficiency2.
  #
  # @return [void]
  def compatible_with_job_proficiency
    return unless position == -1 # Only validate mainhand
    return unless weapon.present? && party&.job.present?

    job = party.job
    weapon_prof = weapon.proficiency

    # Weapon proficiency must match one of the job's proficiencies
    unless [job.proficiency1, job.proficiency2].include?(weapon_prof)
      errors.add(:weapon, 'proficiency must match job proficiency for mainhand')
    end
  end

  ##
  # Determines if the grid weapon should be marked as mainhand based on its position.
  #
  # If the grid weapon's position is -1, sets the `mainhand` attribute to true.
  #
  # @return [void]
  def out_of_sync_bullet_positions
    return [] unless collection_weapon.present?

    grid_by_pos = grid_weapon_bullets.index_by(&:position)
    collection_by_pos = collection_weapon.collection_weapon_bullets.index_by(&:position)
    positions = grid_by_pos.keys | collection_by_pos.keys
    positions.sort.reject do |position|
      grid_by_pos[position]&.bullet_id == collection_by_pos[position]&.bullet_id
    end
  end

  def assign_mainhand
    self.mainhand = (position == -1)
  end

  ##
  # Sets default exorcism_level to 1 for befoulment weapons if not provided.
  #
  # @return [void]
  def set_default_uncap_level
    self.uncap_level ||= 0
  end

  def increment_party_counter
    Party.increment_counter(:weapons_count, party_id)
  end

  def decrement_party_counter
    Party.decrement_counter(:weapons_count, party_id)
  end

  def set_default_exorcism_level
    return unless weapon.present?
    return unless exorcism_level.nil? || exorcism_level.zero?
    return unless weapon_augment_type == 'befoulment'

    self.exorcism_level = 1
  end
end
