# frozen_string_literal: true

##
# This file defines the Party model which represents a party in the application.
# It encapsulates the logic for managing party records including associations with
# characters, weapons, summons, and other related models. The Party model handles
# validations, nested attributes, preview generation, and various business logic
# to ensure consistency and integrity of party data.
#
# @note The model uses ActiveRecord associations, enums, and custom validations.
#
# @!attribute [rw] preview_state
#   @return [Integer] the current state of the preview, represented as an enum:
#     - 0: pending
#     - 1: queued
#     - 2: in_progress
#     - 3: generated
#     - 4: failed
# @!attribute [rw] element
#   @return [Integer] the elemental type associated with the party.
# @!attribute [rw] clear_time
#   @return [Integer] the clear time for the party.
# @!attribute [rw] master_level
#   @return [Integer, nil] the master level of the party.
# @!attribute [rw] button_count
#   @return [Integer, nil] the button count, if applicable.
# @!attribute [rw] chain_count
#   @return [Integer, nil] the chain count, if applicable.
# @!attribute [rw] turn_count
#   @return [Integer, nil] the turn count, if applicable.
# @!attribute [rw] ultimate_mastery
#   @return [Integer, nil] the ultimate mastery level, if applicable.
# @!attribute [rw] visibility
#   @return [Integer] the visibility of the party:
#     - 1: Public
#     - 2: Unlisted
#     - 3: Private
# @!attribute [rw] shortcode
#   @return [String] a unique shortcode for the party.
# @!attribute [rw] edit_key
#   @return [String] an edit key for parties without an associated user.
#
# @!attribute [r] source_party
#   @return [Party, nil] the original party if this is a remix.
# @!attribute [r] remixes
#   @return [Array<Party>] a collection of parties remixed from this party.
# @!attribute [r] user
#   @return [User, nil] the user who created the party.
# @!attribute [r] raid
#   @return [Raid, nil] the associated raid.
# @!attribute [r] job
#   @return [Job, nil] the associated job.
# @!attribute [r] accessory
#   @return [JobAccessory, nil] the accessory used in the party.
# @!attribute [r] skill0
#   @return [JobSkill, nil] the primary skill.
# @!attribute [r] skill1
#   @return [JobSkill, nil] the secondary skill.
# @!attribute [r] skill2
#   @return [JobSkill, nil] the tertiary skill.
# @!attribute [r] skill3
#   @return [JobSkill, nil] the quaternary skill.
# @!attribute [r] guidebook1
#   @return [Guidebook, nil] the first guidebook.
# @!attribute [r] guidebook2
#   @return [Guidebook, nil] the second guidebook.
# @!attribute [r] guidebook3
#   @return [Guidebook, nil] the third guidebook.
# @!attribute [r] characters
#   @return [Array<GridCharacter>] the characters associated with this party.
# @!attribute [r] weapons
#   @return [Array<GridWeapon>] the weapons associated with this party.
# @!attribute [r] summons
#   @return [Array<GridSummon>] the summons associated with this party.
# @!attribute [r] favorites
#   @return [Array<Favorite>] the favorites that include this party.
class Party < ApplicationRecord
  include GranblueEnums

  SUMMON_SERIES_MOD = {
    'magna' => 'omega',
    'optimus' => 'primal',
    'demi-optimus' => 'primal',
    'bellum' => 'odious'
  }.freeze

  # Define preview_state as an enum.
  attribute :preview_state, :integer
  enum :preview_state, { pending: 0, queued: 1, in_progress: 2, generated: 3, failed: 4 }

  # ActiveRecord Associations
  belongs_to :source_party,
             class_name: 'Party',
             foreign_key: :source_party_id,
             optional: true

  has_many :remixes, -> { order(created_at: :desc) },
           class_name: 'Party',
           foreign_key: 'source_party_id',
           inverse_of: :source_party,
           dependent: :nullify

  belongs_to :user, optional: true
  belongs_to :collection_source_user, class_name: 'User', optional: true
  belongs_to :raid, optional: true
  belongs_to :job, optional: true

  belongs_to :accessory,
             foreign_key: 'accessory_id',
             class_name: 'JobAccessory',
             optional: true

  belongs_to :skill0,
             foreign_key: 'skill0_id',
             class_name: 'JobSkill',
             optional: true

  belongs_to :skill1,
             foreign_key: 'skill1_id',
             class_name: 'JobSkill',
             optional: true

  belongs_to :skill2,
             foreign_key: 'skill2_id',
             class_name: 'JobSkill',
             optional: true

  belongs_to :skill3,
             foreign_key: 'skill3_id',
             class_name: 'JobSkill',
             optional: true

  belongs_to :guidebook1,
             foreign_key: 'guidebook1_id',
             class_name: 'Guidebook',
             optional: true

  belongs_to :guidebook2,
             foreign_key: 'guidebook2_id',
             class_name: 'Guidebook',
             optional: true

  belongs_to :guidebook3,
             foreign_key: 'guidebook3_id',
             class_name: 'Guidebook',
             optional: true

  has_many :characters, -> { where(is_substitute: false) },
           foreign_key: 'party_id',
           class_name: 'GridCharacter',
           inverse_of: :party

  has_many :weapons, -> { where(is_substitute: false) },
           foreign_key: 'party_id',
           class_name: 'GridWeapon',
           inverse_of: :party

  has_many :summons, -> { where(is_substitute: false) },
           foreign_key: 'party_id',
           class_name: 'GridSummon',
           inverse_of: :party

  has_many :all_characters,
           foreign_key: 'party_id',
           class_name: 'GridCharacter',
           dependent: :delete_all

  has_many :all_weapons,
           foreign_key: 'party_id',
           class_name: 'GridWeapon',
           dependent: :delete_all

  has_many :all_summons,
           foreign_key: 'party_id',
           class_name: 'GridSummon',
           dependent: :delete_all

  has_many :favorites, dependent: :destroy
  has_many :party_shares, dependent: :destroy
  has_many :shared_crews, through: :party_shares, source: :shareable, source_type: 'Crew'

  accepts_nested_attributes_for :all_characters
  accepts_nested_attributes_for :all_summons
  accepts_nested_attributes_for :all_weapons

  before_create :set_shortcode
  before_create :set_edit_key

  after_commit :update_element!, on: %i[create update]
  after_commit :update_extra!, on: %i[create update]

  # Amoeba configuration
  amoeba do
    set weapons_count: 0
    set characters_count: 0
    set summons_count: 0

    nullify :description
    nullify :shortcode
    nullify :edit_key

    include_association :all_characters
    include_association :all_weapons
    include_association :all_summons
  end

  after_create :create_remapped_substitutions, if: -> { @_source_party_for_remap.present? }

  # ActiveRecord Validations
  validate :skills_are_unique
  validate :guidebooks_are_unique

  # For element, validate numericality and inclusion using the allowed values from GranblueEnums.
  validates :element,
            numericality: { only_integer: true },
            inclusion: {
              in: GranblueEnums::ELEMENTS.values,
              message: "must be one of #{GranblueEnums::ELEMENTS.map { |name, value| "#{value} (#{name})" }.join(', ')}"
            },
            allow_nil: true

  validates :clear_time, numericality: { only_integer: true }
  validates :master_level, numericality: { only_integer: true }, allow_nil: true
  validates :button_count, numericality: { only_integer: true }, allow_nil: true
  validates :chain_count, numericality: { only_integer: true }, allow_nil: true
  validates :turn_count, numericality: { only_integer: true }, allow_nil: true
  validates :summon_count, numericality: { only_integer: true }, allow_nil: true
  validates :ultimate_mastery, numericality: { only_integer: true }, allow_nil: true

  # YouTube URL validation regex
  YOUTUBE_REGEX = %r{\A(?:https?://)?(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)[\w-]+}
  validates :video_url, format: { with: YOUTUBE_REGEX, message: 'must be a valid YouTube URL' }, allow_blank: true

  # Validate visibility (allowed values: 1, 2, or 3).
  validates :visibility,
            numericality: { only_integer: true },
            inclusion: {
              in: [1, 2, 3],
              message: 'must be 1 (Public), 2 (Unlisted), or 3 (Private)'
            }

  after_commit :schedule_preview_generation, if: :should_generate_preview?

  #########################
  # Public API Methods
  #########################

  ##
  # Checks if the party is a remix of another party.
  #
  # @return [Boolean] true if the party is a remix; false otherwise.
  attr_writer :_source_party_for_remap

  def remix?
    !source_party.nil?
  end

  ##
  # Returns the blueprint class used for rendering the party.
  #
  # @return [Class] the PartyBlueprint class.
  def blueprint
    PartyBlueprint
  end

  ##
  # Determines if the party is public.
  #
  # @return [Boolean] true if the party is public; false otherwise.
  def public?
    visibility == 1
  end

  ##
  # Determines if the party is unlisted.
  #
  # @return [Boolean] true if the party is unlisted; false otherwise.
  def unlisted?
    visibility == 2
  end

  ##
  # Determines if the party is private.
  #
  # @return [Boolean] true if the party is private; false otherwise.
  def private?
    visibility == 3
  end

  ##
  # Checks if the party is shared with a specific crew.
  #
  # @param crew [Crew] the crew to check.
  # @return [Boolean] true if shared with the crew; false otherwise.
  def shared_with_crew?(crew)
    return false unless crew

    party_shares.exists?(shareable_type: 'Crew', shareable_id: crew.id)
  end

  ##
  # Checks if a user can view this party based on visibility and sharing rules.
  # A user can view if:
  # - The party is public
  # - The party is unlisted (accessible via direct link)
  # - They own the party
  # - They are an admin
  # - The party is shared with a crew they belong to
  #
  # @param user [User, nil] the user to check.
  # @return [Boolean] true if the user can view the party; false otherwise.
  def viewable_by?(user)
    return true if public?
    return true if unlisted?
    return true if user && user_id == user.id
    return true if user&.admin?
    return true if user&.crew && shared_with_crew?(user.crew)

    false
  end

  ##
  # Checks if the party is favorited by a given user.
  #
  # @param user [User, nil] the user to check for favoritism.
  # @return [Boolean] true if the party is favorited by the user; false otherwise.
  def favorited?(user)
    return false unless user

    Rails.cache.fetch("party_#{id}_favorited_by_#{user.id}", expires_in: 1.hour) do
      Favorite.exists?(user_id: user.id, party_id: id)
    end
  end

  def mod_and_side
    main_summon = summons.detect { |gs| gs.main? }&.summon
    friend_summon = summons.detect { |gs| gs.friend? }&.summon
    return nil unless main_summon && friend_summon

    main_type = SUMMON_SERIES_MOD[main_summon.summon_series&.slug]
    friend_type = SUMMON_SERIES_MOD[friend_summon.summon_series&.slug]

    if main_type && main_type == friend_type
      { mod: main_type, side: 'double' }
    elsif main_type
      { mod: main_type, side: 'single' }
    elsif friend_type
      { mod: friend_type, side: 'single' }
    else
      { mod: 'unboosted', side: 'none' }
    end
  end

  def recompute_boost!
    result = mod_and_side
    new_mod = result&.dig(:mod)
    update_column(:boost_mod, new_mod) if boost_mod != new_mod
  end

  def recompute_side!
    result = mod_and_side
    new_side = result&.dig(:side)
    update_column(:boost_side, new_side) if boost_side != new_side
  end

  ##
  # Checks if the party has any orphaned grid items.
  #
  # An orphaned item is one whose linked collection item has been deleted,
  # indicating the user no longer has that item in their game inventory.
  #
  # @return [Boolean] true if the party has orphaned weapons, summons, or artifacts.
  def has_orphaned_items?
    weapons.orphaned.exists? ||
      summons.orphaned.exists? ||
      characters.joins(:grid_artifact).where(grid_artifacts: { orphaned: true }).exists?
  end

  ##
  # Determines if the party meets the minimum requirements for preview generation.
  #
  # The party must have at least one weapon, one character, and one summon.
  #
  # @return [Boolean] true if the party is ready for preview; false otherwise.
  def ready_for_preview?
    return false if weapons_count < 1 # At least 1 weapon
    return false if characters_count < 1 # At least 1 character
    return false if summons_count < 1 # At least 1 summon

    true
  end

  ##
  # Determines whether a new preview should be generated for the party.
  #
  # The method checks various conditions such as preview state, expiration, and content changes.
  #
  # @return [Boolean] true if a preview generation should be triggered; false otherwise.
  def should_generate_preview?
    return false unless ready_for_preview?

    return true if preview_pending?
    return true if preview_failed_and_stale?
    return true if preview_generated_and_expired?
    return true if preview_content_changed_and_stale?

    false
  end

  ##
  # Checks whether the current preview has expired based on a predefined expiry period.
  #
  # @return [Boolean] true if the preview is expired; false otherwise.
  def preview_expired?
    preview_generated_at.nil? ||
      preview_generated_at < PreviewService::Coordinator::PREVIEW_EXPIRY.ago
  end

  ##
  # Determines if the content relevant for preview generation has changed.
  #
  # @return [Boolean] true if any preview-relevant attributes have changed; false otherwise.
  def preview_content_changed?
    saved_changes.keys.any? { |attr| preview_relevant_attributes.include?(attr) }
  end

  ##
  # Schedules the generation of a party preview if applicable.
  #
  # This method updates the preview state to 'queued' and enqueues a background job
  # to generate the preview.
  #
  # @return [void]
  def schedule_preview_generation
    return if %w[queued in_progress].include?(preview_state.to_s)

    update_column(:preview_state, self.class.preview_states[:queued])
    GeneratePartyPreviewJob.perform_later(id)
  end

  private

  #########################
  # Preview Generation Helpers
  #########################

  ##
  # Checks if the preview is pending.
  #
  # @return [Boolean] true if preview_state is nil or 'pending'.
  def preview_pending?
    preview_state.nil? || preview_state == 'pending'
  end

  ##
  # Checks if the preview generation failed and the preview is stale.
  #
  # @return [Boolean] true if preview_state is 'failed' and preview_generated_at is older than 5 minutes.
  def preview_failed_and_stale?
    preview_state == 'failed' && preview_generated_at < 5.minutes.ago
  end

  ##
  # Checks if the generated preview is expired.
  #
  # @return [Boolean] true if preview_state is 'generated' and the preview is expired.
  def preview_generated_and_expired?
    preview_state == 'generated' && preview_expired?
  end

  ##
  # Checks if the preview content has changed and the preview is stale.
  #
  # @return [Boolean] true if the preview content has changed and preview_generated_at is nil or older than 5 minutes.
  def preview_content_changed_and_stale?
    preview_content_changed? && (preview_generated_at.nil? || preview_generated_at < 5.minutes.ago)
  end

  #########################
  # Uniqueness Validation Helpers
  #########################

  ##
  # Validates uniqueness for a given set of associations.
  #
  # @param associations [Array<Object, nil>] an array of associated objects.
  # @param attribute_names [Array<Symbol>] the corresponding attribute names for each association.
  # @param error_key [Symbol] the key for a generic error.
  # @return [void]
  def validate_uniqueness_of_associations(associations, attribute_names, error_key)
    filtered = associations.compact
    return if filtered.uniq.length == filtered.length

    associations.each_with_index do |assoc, index|
      next if assoc.nil?

      errors.add(attribute_names[index], 'must be unique') if associations[0...index].include?(assoc)
    end
    errors.add(error_key, 'must be unique')
  end

  ##
  # Validates that the selected skills are unique.
  #
  # @return [void]
  def skills_are_unique
    validate_uniqueness_of_associations([skill0, skill1, skill2, skill3],
                                        %i[skill0 skill1 skill2 skill3],
                                        :job_skills)
  end

  ##
  # Validates that the selected guidebooks are unique.
  #
  # @return [void]
  def guidebooks_are_unique
    validate_uniqueness_of_associations([guidebook1, guidebook2, guidebook3],
                                        %i[guidebook1 guidebook2 guidebook3],
                                        :guidebooks)
  end

  ##
  # Provides a list of attributes that are relevant for determining if the preview content has changed.
  #
  # @return [Array<String>] an array of attribute names.
  def preview_relevant_attributes
    %w[
      name job_id element weapons_count characters_count summons_count
      full_auto auto_guard charge_attack clear_time
    ]
  end

  #########################
  # Substitution Remapping
  #########################

  def create_remapped_substitutions
    source = @_source_party_for_remap
    return unless source

    subs = Substitution.where(grid_type: 'GridCharacter', grid_id: source.all_characters.select(:id))
                       .or(Substitution.where(grid_type: 'GridWeapon', grid_id: source.all_weapons.select(:id)))
                       .or(Substitution.where(grid_type: 'GridSummon', grid_id: source.all_summons.select(:id)))
                       .to_a
    return if subs.empty?

    remap_for_type(subs, 'GridCharacter', all_characters.reload, source.all_characters, :character_id)
    remap_for_type(subs, 'GridWeapon', all_weapons.reload, source.all_weapons, :weapon_id)
    remap_for_type(subs, 'GridSummon', all_summons.reload, source.all_summons, :summon_id)
  end

  def remap_for_type(subs, grid_type, new_items, old_items, item_fk)
    type_subs = subs.select { |s| s.grid_type == grid_type }
    return if type_subs.empty?

    # Map old grid item ID → new grid item by matching item FK + position + is_substitute
    id_map = {}
    old_items.each do |old_item|
      new_item = new_items.detect do |ni|
        ni.send(item_fk) == old_item.send(item_fk) &&
          ni.position == old_item.position &&
          ni.is_substitute? == old_item.is_substitute?
      end
      id_map[old_item.id] = new_item.id if new_item
    end

    type_subs.each do |sub|
      new_grid_id = id_map[sub.grid_id]
      new_sub_grid_id = id_map[sub.substitute_grid_id]
      next unless new_grid_id && new_sub_grid_id

      Substitution.create!(
        grid_type: grid_type,
        grid_id: new_grid_id,
        substitute_grid_type: sub.substitute_grid_type,
        substitute_grid_id: new_sub_grid_id,
        position: sub.position
      )
    end
  end

  #########################
  # Miscellaneous Helpers
  #########################

  ##
  # Updates the party's element based on its main weapon.
  #
  # Finds the main weapon (position -1) and updates the party's element if it differs.
  #
  # @return [void]
  def update_element!
    main_weapon = weapons.detect { |gw| gw.position.to_i == -1 }
    new_element = main_weapon&.weapon&.element
    update_column(:element, new_element) if new_element.present? && element != new_element
  end

  ##
  # Updates the party's extra flag based on weapon positions.
  #
  # Sets the extra flag to true if any weapon is in an extra position, otherwise false.
  #
  # @return [void]
  def update_extra!
    new_extra = weapons.any? { |gw| GridWeapon::EXTRA_POSITIONS.include?(gw.position.to_i) }
    update_column(:extra, new_extra) if extra != new_extra
  end

  ##
  # Sets a unique shortcode for the party before creation.
  #
  # Generates a random string and assigns it to the shortcode attribute.
  #
  # @return [void]
  def set_shortcode
    self.shortcode = random_string
  end

  ##
  # Sets an edit key for the party before creation if no associated user is present.
  #
  # The edit key is generated using a SHA1 hash based on the current time and a random value.
  #
  # @return [void]
  def set_edit_key
    return if user

    self.edit_key ||= Digest::SHA1.hexdigest([Time.now, rand].join)
  end

  ##
  # Generates a random alphanumeric string used for the party shortcode.
  #
  # @return [String] a random string of 6 characters.
  def random_string
    num_chars = 6
    o = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten
    (0...num_chars).map { o[rand(o.length)] }.join
  end
end
