# frozen_string_literal: true

##
# Model representing a grid summon within a party.
#
# A GridSummon is associated with a specific {Summon} and {Party} and is responsible for
# enforcing rules on positions, uncap levels, and transcendence steps based on the associated summon’s flags.
#
# @!attribute [r] summon
#   @return [Summon] the associated summon.
# @!attribute [r] party
#   @return [Party] the associated party.
class GridSummon < ApplicationRecord
  belongs_to :summon, foreign_key: :summon_id, primary_key: :id

  belongs_to :party,
             inverse_of: :summons
  belongs_to :collection_summon, optional: true

  has_many :substitutions, as: :grid, dependent: :destroy
  has_many :substitute_of, class_name: 'Substitution', as: :substitute_grid, dependent: :destroy
  validates_presence_of :party

  # Associations the nested blueprint walks. Reused by controllers and the
  # polymorphic substitute-grid preloader so a single source of truth keeps
  # them in sync as the blueprint evolves.
  NESTED_BLUEPRINT_PRELOADS = [
    :collection_summon,
    { summon: :summon_series }
  ].freeze

  # Orphan status scopes
  scope :orphaned, -> { where(orphaned: true) }
  scope :not_orphaned, -> { where(orphaned: false) }

  # Validate that position is provided.
  validates :position, presence: true
  validate :compatible_with_position, on: :create, unless: :is_substitute?

  # Validate that uncap_level is present and numeric, transcendence_step is optional but must be numeric if present.
  validates :uncap_level, presence: true, numericality: { only_integer: true }
  validates :transcendence_step, numericality: { only_integer: true }, allow_nil: true

  # Custom validation to enforce maximum uncap_level based on the associated Summon’s flags.
  validate :validate_uncap_level_based_on_summon_flags

  validate :no_conflicts, on: :create, unless: :is_substitute?

  before_validation :set_default_uncap_level, on: :create

  after_create :increment_party_counter, unless: :is_substitute?
  after_destroy :decrement_party_counter, unless: :is_substitute?

  after_commit :recompute_party_boost!, on: %i[create update destroy]

  # Virtual attribute set by the controller for substitute renders. See
  # GridCharacter#owned for the full rationale.
  attr_accessor :owned

  ##
  # Returns the blueprint for rendering the grid summon.
  #
  # @return [GridSummonBlueprint] the blueprint class for grid summons.
  def blueprint
    GridSummonBlueprint
  end

  ##
  # Marks this grid summon as orphaned and clears its collection link.
  #
  # @return [Boolean] true if the update succeeded
  def mark_orphaned!
    update!(orphaned: true, collection_summon_id: nil)
  end

  # Maps camelCase keys emitted by #out_of_sync_fields to column names so the
  # frontend can sync individual sections instead of overwriting every field.
  SYNC_FIELD_MAP = {
    'uncapLevel' => %i[uncap_level],
    'transcendenceStep' => %i[transcendence_step]
  }.freeze

  ALL_SYNC_COLUMNS = SYNC_FIELD_MAP.values.flatten.uniq.freeze

  ##
  # Syncs customizations from the linked collection summon.
  #
  # @param fields [Array<String>, nil] optional list of camelCase keys to sync
  # @return [Boolean] true if sync was performed, false if no collection link
  def sync_from_collection!(fields: nil)
    return false unless collection_summon.present?

    columns = sync_columns_for(fields)
    return true if columns.empty?

    update!(columns.index_with { |col| collection_summon.public_send(col) })
    true
  end

  ##
  # Syncs customizations from this grid summon to the linked collection summon.
  #
  # @param fields [Array<String>, nil] optional list of camelCase keys to sync
  # @return [Boolean] true if sync was performed, false if no collection link
  def sync_to_collection!(fields: nil)
    return false unless collection_summon.present?

    columns = sync_columns_for(fields)
    return true if columns.empty?

    collection_summon.update!(columns.index_with { |col| public_send(col) })
    true
  end

  ##
  # Checks if grid summon is out of sync with collection.
  #
  # @return [Boolean] true if any customization differs from collection
  def out_of_sync?
    out_of_sync_fields.any?
  end

  ##
  # Returns the list of fields that differ from the linked collection summon.
  # Uses camelCase keys matching the frontend's grid item shape.
  def out_of_sync_fields
    return [] unless collection_summon.present?

    fields = []
    fields << 'uncapLevel' if uncap_level != collection_summon.uncap_level
    fields << 'transcendenceStep' if transcendence_step != collection_summon.transcendence_step
    fields
  end

  ##
  # Returns any conflicting grid summon for the given party.
  #
  # If the associated summon has a limit, this method searches the party's grid summons to find
  # any that conflict based on the summon ID.
  #
  # @param party [Party] the party in which to check for conflicts.
  # @return [GridSummon, nil] the conflicting grid summon if found, otherwise nil.
  def conflicts(party)
    return unless summon&.limit

    party.summons.find do |grid_summon|
      return unless grid_summon.id

      grid_summon if summon.id == grid_summon.summon.id
    end
  end

  private

  def sync_columns_for(fields)
    return ALL_SYNC_COLUMNS if fields.blank?

    fields.flat_map { |key| SYNC_FIELD_MAP[key] || [] }.uniq
  end

  def set_default_uncap_level
    self.uncap_level ||= 0
  end

  def increment_party_counter
    Party.increment_counter(:summons_count, party_id)
  end

  def decrement_party_counter
    Party.decrement_counter(:summons_count, party_id)
  end

  def recompute_party_boost!
    return if is_substitute?
    return unless main? || friend?

    party.reload
    party.recompute_boost!
    party.recompute_side!
  end

  ##
  # Validates the uncap_level based on the associated Summon’s flags.
  #
  # This method delegates to specific validation methods for FLB, ULB, and transcendence limits.
  #
  # @return [void]
  def validate_uncap_level_based_on_summon_flags
    return unless summon

    validate_flb_limit
    validate_ulb_limit
    validate_transcendence_limits
  end

  ##
  # Validates that the uncap_level does not exceed 3 if the associated Summon does not have the FLB flag.
  #
  # @return [void]
  def validate_flb_limit
    return unless !summon.flb && uncap_level.to_i > 3

    errors.add(:uncap_level, 'cannot be greater than 3 if summon does not have FLB')
  end

  ##
  # Validates that the uncap_level does not exceed 4 if the associated Summon does not have the ULB flag.
  #
  # @return [void]
  def validate_ulb_limit
    return unless !summon.ulb && uncap_level.to_i > 4

    errors.add(:uncap_level, 'cannot be greater than 4 if summon does not have ULB')
  end

  ##
  # Validates the uncap_level and transcendence_step based on whether the associated Summon supports transcendence.
  #
  # If the summon does not support transcendence, the uncap_level must not exceed 5 and the transcendence_step must be 0.
  #
  # @return [void]
  def validate_transcendence_limits
    if summon.transcendence
      errors.add(:transcendence_step, 'transcendence step too high') if transcendence_step.to_i > 5
    else
      errors.add(:uncap_level, 'cannot be greater than 5 if summon does not have transcendence') if uncap_level.to_i > 5
      errors.add(:transcendence_step, 'must be 0 if summon does not have transcendence') if transcendence_step.to_i.positive?
    end
  end

  ##
  # Validates that there are no conflicting grid summons in the party.
  #
  # If a conflict is found (i.e. another grid summon exists that conflicts with this one),
  # an error is added to the :series attribute.
  #
  # @return [void]
  def no_conflicts
    # Check if the grid summon conflicts with any of the other grid summons in the party
    errors.add(:series, 'must not conflict with existing summons') unless conflicts(party).nil?
  end

  ##
  # Validates whether the grid summon can be added to the desired position.
  #
  # Sub summon positions (5+) require the summon to have subaura.
  # Friend summons are exempt from this check.
  #
  # @return [void]
  def compatible_with_position
    return unless summon && !friend && position.to_i.in?(4..5) && !summon.subaura

    errors.add(:position, 'must have subaura for position')
  end
end
