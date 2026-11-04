# frozen_string_literal: true

##
# This file defines the Party model which represents a party in the application.
# It encapsulates the logic for managing party records including associations with
# characters, weapons, summons, and other related models. The Party model handles
# validations, nested attributes, and various business logic
# to ensure consistency and integrity of party data.
#
# @note The model uses ActiveRecord associations, enums, and custom validations.
#
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
# @!attribute [rw] ultimate_mastery_level
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
  include SolomonisParty
  include Party::Visibility
  include Party::Ranking
  include Party::CollectionLinks

  alias_attribute :ultimate_mastery, :ultimate_mastery_level

  SUMMON_SERIES_MOD = {
    'magna' => 'omega',
    'optimus' => 'primal',
    'demi-optimus' => 'primal',
    'bellum' => 'odious'
  }.freeze

  # ActiveRecord Associations
  belongs_to :source_party,
             class_name: 'Party',
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
  belongs_to :difficulty, optional: true

  belongs_to :accessory,
             class_name: 'JobAccessory',
             optional: true

  belongs_to :skill0,
             class_name: 'JobSkill',
             optional: true

  belongs_to :skill1,
             class_name: 'JobSkill',
             optional: true

  belongs_to :skill2,
             class_name: 'JobSkill',
             optional: true

  belongs_to :skill3,
             class_name: 'JobSkill',
             optional: true

  belongs_to :guidebook1,
             class_name: 'Guidebook',
             optional: true

  belongs_to :guidebook2,
             class_name: 'Guidebook',
             optional: true

  belongs_to :guidebook3,
             class_name: 'Guidebook',
             optional: true

  # The filtered views of the grid; the all_* associations below own the rows
  # and destroy them.
  has_many :characters, -> { where(is_substitute: false) },
           foreign_key: 'party_id',
           dependent: nil,
           class_name: 'GridCharacter',
           inverse_of: :party

  has_many :weapons, -> { where(is_substitute: false) },
           foreign_key: 'party_id',
           dependent: nil,
           class_name: 'GridWeapon',
           inverse_of: :party

  has_many :summons, -> { where(is_substitute: false) },
           foreign_key: 'party_id',
           dependent: nil,
           class_name: 'GridSummon',
           inverse_of: :party

  # Uses :destroy on all three so the grid items' own callbacks fire — most
  # importantly `has_many :substitutions, ..., dependent: :destroy`. :delete_all
  # would skip callbacks and leave orphan substitution rows pointing at deleted
  # grid ids.
  has_many :all_characters,
           class_name: 'GridCharacter',
           dependent: :destroy,
           inverse_of: :party

  has_many :all_weapons,
           class_name: 'GridWeapon',
           dependent: :destroy,
           inverse_of: :party

  has_many :all_summons,
           class_name: 'GridSummon',
           dependent: :destroy,
           inverse_of: :party

  has_many :favorites, dependent: :destroy
  has_many :party_stickers, dependent: :delete_all
  has_many :featured_parties, dependent: :delete_all
  has_many :playlist_parties, dependent: :destroy
  has_many :playlists, through: :playlist_parties
  has_many :party_shares, dependent: :destroy
  has_many :shared_crews, through: :party_shares, source: :shareable, source_type: 'Crew'

  # Public-facing nested attributes target the filtered associations (no substitutes),
  # matching the *_attributes keys the controller permits and pre-substitutions clients send.
  accepts_nested_attributes_for :characters
  accepts_nested_attributes_for :summons
  accepts_nested_attributes_for :weapons

  # Internal flows (e.g. remix re-mapping) need to write to the unfiltered scopes.
  accepts_nested_attributes_for :all_characters
  accepts_nested_attributes_for :all_summons
  accepts_nested_attributes_for :all_weapons

  before_create :set_shortcode
  before_create :set_edit_key

  after_commit :update_element!, on: %i[create update]
  after_commit :update_extra!, on: %i[create update]

  # Included here, after the associations and the commit hooks above, so
  # their callbacks keep their place in the chains: the remix after_create
  # follows the associations' autosave hooks, the difficulty recompute is the
  # last after_commit, and the loadout validations follow the associated-record
  # validations.
  include Party::RemixSubstitutions
  include Party::DifficultyRecompute
  include Party::LoadoutValidations

  # Amoeba configuration
  amoeba do
    set weapons_count: 0
    set characters_count: 0
    set summons_count: 0

    nullify :description
    nullify :shortcode
    nullify :edit_key
    nullify :difficulty_id
    nullify :difficulty_score
    nullify :difficulty_breakdown
    nullify :difficulty_computed_at
    nullify :difficulty_ruleset_version

    include_association :all_characters
    include_association :all_weapons
    include_association :all_summons
    # Remixes keep the Evoking Solomonis setup (route, pledge, blessings, seal
    # state and unseal priority on the grids) but never the guidebook;
    # SolomonisExpedition's own amoeba config clears the fields that describe
    # the original expedition.
    include_association :solomonis_expedition
    include_association :party_blessings
  end

  # ActiveRecord Validations
  validates :name,
            profanity: { languages: %i[en ja], tier: :moderate, message: 'contains inappropriate language' },
            allow_blank: true

  validates :description,
            profanity: { languages: %i[en ja], tier: :moderate, message: 'contains inappropriate language' },
            allow_blank: true
  validates :description, rich_text_description: true, if: :description_changed?

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
  validates :ultimate_mastery_level, numericality: { only_integer: true }, allow_nil: true

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

  #########################
  # Public API Methods
  #########################

  ##
  # Bumps the user-visible last_updated timestamp without touching updated_at.
  # Use this for user-initiated changes to grid items that don't go through party.save.
  #
  # @return [Boolean] true if the update succeeded.
  def mark_updated!
    result = update_column(:last_updated, Time.current) # rubocop:disable Rails/SkipsModelValidations -- bumps last_updated only, not updated_at
    enqueue_difficulty_recompute!
    result
  end

  ##
  # Returns true iff any grid item in this party has at least one substitution.
  #
  # Uses a single EXISTS query over substitutions, scoped by polymorphic
  # (grid_type, grid_id) pairs. Most parties have zero substitutes, so this
  # cheap predicate lets the read path skip the heavier preload_substitute_grids!
  # work in SubstituteGridPreloading.
  #
  # @return [Boolean]
  def substitutions?
    return @substitutions if defined?(@substitutions)

    @substitutions = Substitution
                     .where(grid_type: 'GridCharacter', grid_id: GridCharacter.where(party_id: id).select(:id))
                     .or(Substitution.where(grid_type: 'GridWeapon', grid_id: GridWeapon.where(party_id: id).select(:id)))
                     .or(Substitution.where(grid_type: 'GridSummon', grid_id: GridSummon.where(party_id: id).select(:id)))
                     .exists?
  end

  ##
  # Checks if the party is a remix of another party.
  #
  # @return [Boolean] true if the party is a remix; false otherwise.
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
    main_summon = summons.detect(&:main?)&.summon
    friend_summon = summons.detect(&:friend?)&.summon
    return nil unless main_summon && friend_summon

    summon_boost(SUMMON_SERIES_MOD[main_summon.summon_series&.slug],
                 SUMMON_SERIES_MOD[friend_summon.summon_series&.slug])
  end

  # rubocop:disable Rails/SkipsModelValidations -- derived columns written from grid callbacks; a save would rerun the party callbacks
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
  # rubocop:enable Rails/SkipsModelValidations

  ##
  # Checks if the party has any orphaned grid items.
  #
  # An orphaned item is one whose linked collection item has been deleted,
  # indicating the user no longer has that item in their game inventory.
  #
  # @return [Boolean] true if the party has orphaned weapons, summons, or artifacts.
  def orphaned_items?
    if weapons.loaded? && summons.loaded? && characters.loaded?
      loaded_items_orphaned?
    else
      weapons.orphaned.exists? ||
        summons.orphaned.exists? ||
        characters.joins(:grid_artifact).exists?(grid_artifacts: { orphaned: true })
    end
  end

  private

  ##
  # The boost a main and friend summon series give together.
  #
  # @param main_type [String, nil] the main summon's mod ('omega', 'primal', 'odious').
  # @param friend_type [String, nil] the friend summon's mod.
  # @return [Hash] the mod and the side ('double', 'single' or 'none').
  def summon_boost(main_type, friend_type)
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

  # #orphaned_items? for a party whose grid is already loaded.
  def loaded_items_orphaned?
    weapons.any?(&:orphaned?) ||
      summons.any?(&:orphaned?) ||
      characters.any? { |c| c.grid_artifact&.orphaned? }
  end

  ##
  # Updates the party's element based on its main weapon.
  #
  # Finds the main weapon (position -1) and updates the party's element if it differs.
  #
  # @return [void]
  # rubocop:disable Rails/SkipsModelValidations -- runs in after_commit; a save would commit again and rerun these callbacks
  def update_element!
    # Evoking Solomonis parties take their element from the route Evoker.
    return if solomonis?

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
  # rubocop:enable Rails/SkipsModelValidations

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
  # The edit key is 128 bits from SecureRandom. Keys issued before this
  # (40-character SHA1 hex) stay valid.
  #
  # @return [void]
  def set_edit_key
    return if user

    self.edit_key ||= SecureRandom.hex(16)
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
