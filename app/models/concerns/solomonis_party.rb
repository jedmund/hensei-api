# frozen_string_literal: true

##
# Evoking Solomonis behaviour for Party.
#
# A party is a Solomonis party when it has a SolomonisExpedition. Its raid is
# the route Evoker's zone and its element the route Evoker's element; both are
# set here whenever the route is set, and a party in a Solomonis zone without
# an expedition (route Evoker) is invalid.
#
# Moving a Solomonis party to a non-Solomonis raid deletes its expedition,
# blessings and guidebook and clears seal state, unseal priority and
# brought_by_blessing.
#
# Entry points for controllers and importers:
# - #assign_solomonis_route(character): set or change the route Evoker.
# - #replace_solomonis_blessings!(levels): write a whole blessing loadout.
# - #replace_unseal_priority!(items): write the whole unseal priority (the
#   weapon and summon lists, numbered separately) (SolomonisPartySeals).
# - #replace_solomonis_guide_effects!(entries): write the whole guidebook.
# - #apply_solomonis_seal_states!(weapons:, summons:) (SolomonisPartySeals): set
#   imported seal state by position.
# - #recompute_solomonis_state! (SolomonisPartySeals): re-derive seal state and close unseal priority
#   gaps after grid or blessing writes that bypass model callbacks.
module SolomonisParty
  extend ActiveSupport::Concern

  # Weapon positions that always start unsealed: the mainhand and the top-left two.
  STARTING_WEAPON_POSITIONS = [-1, 0, 1].freeze
  # Starts unsealed too when Justice is equipped.
  JUSTICE_WEAPON_POSITION = 2
  # The route Evoker and up to 4 allies (The Hanged Man's ally is one of them).
  CHARACTER_LIMIT = 5

  included do
    include SolomonisPartySeals

    has_one :solomonis_expedition, dependent: :destroy, inverse_of: :party
    has_many :party_blessings, dependent: :destroy, inverse_of: :party
    has_many :expedition_guide_effects, dependent: :destroy, inverse_of: :party

    accepts_nested_attributes_for :solomonis_expedition, update_only: true

    before_validation :sync_solomonis_route
    validate :solomonis_consistency

    after_save :clear_solomonis_data!, if: -> { @leaving_solomonis }
    after_save :recompute_solomonis_state_after_expedition_change
    after_save :sync_solomonis_expedition_user, if: :saved_change_to_user_id?
  end

  #########################
  # Queries
  #########################

  # True when the party has an expedition (and isn't leaving the mode in this save).
  def solomonis?
    expedition = solomonis_expedition
    expedition.present? && !expedition.marked_for_destruction?
  end

  # True when the party's raid is an Evoking Solomonis zone.
  def solomonis_zone?
    raid&.solomonis_zone? || false
  end

  # Whether a blessing (by slug) is equipped. Reads the in-memory association,
  # so it also sees blessings built but not yet saved. The blessings are
  # batch-loaded so the slug check costs one query, not one per blessing.
  def solomonis_blessing?(slug)
    blessings = party_blessings.reject(&:marked_for_destruction?)
    ActiveRecord::Associations::Preloader.new(records: blessings, associations: :arcarum_blessing).call
    blessings.any? { |pb| pb.slug == slug }
  end

  def solomonis_blessing_cost_total
    party_blessings.reject(&:marked_for_destruction?).sum { |pb| pb.cost.to_i }
  end

  # Grid character limit (non-substitutes), or nil outside Solomonis.
  def solomonis_character_limit
    CHARACTER_LIMIT if solomonis?
  end

  # Weapon positions that start unsealed, given the equipped blessings.
  def solomonis_starting_weapon_positions(justice: solomonis_blessing?(ArcarumBlessing::JUSTICE))
    justice ? STARTING_WEAPON_POSITIONS + [JUSTICE_WEAPON_POSITION] : STARTING_WEAPON_POSITIONS
  end

  #########################
  # Writes
  #########################

  ##
  # Sets the route Evoker, building the expedition if needed, and moves the
  # party to the Evoker's zone and element. Doesn't save.
  def assign_solomonis_route(character)
    expedition = solomonis_expedition || build_solomonis_expedition
    expedition.route_evoker = character
    apply_route_to_party(character)
    expedition
  end

  ##
  # Replaces the blessing loadout. Checks the whole set (released, one level per
  # blessing, total cost), clears brought_by_blessing when The Hanged Man is
  # dropped, and recomputes seal state for Justice.
  #
  # Holds the party's row lock (see #lock_solomonis_party!) from the checks
  # to the writes.
  #
  # @param levels [Array<ArcarumBlessingLevel>]
  # @raise [ActiveRecord::RecordInvalid] with errors on :blessings
  def replace_solomonis_blessings!(levels)
    levels = levels.to_a
    transaction do
      lock_solomonis_party!
      errors.clear
      validate_blessing_loadout(levels)
      raise ActiveRecord::RecordInvalid, self if errors.any?

      party_blessings.delete_all
      levels.each { |level| party_blessings.create!(arcarum_blessing_level: level) }
      party_blessings.reset
      unless levels.any? { |l| l.arcarum_blessing.slug == ArcarumBlessing::HANGED_MAN }
        GridCharacter.where(party_id: id).update_all(brought_by_blessing: false)
      end
      recompute_solomonis_state!
    end
    party_blessings.reload
  end

  ##
  # Replaces the guidebook (the effects held at the end of an expedition),
  # under the party's row lock like #replace_solomonis_blessings!.
  #
  # @param entries [Array<Hash>] `{ solomonis_guide_effect: or solomonis_guide_effect_id:, count:,
  #   display_value:, acquired_order:, inherited:, note: }`
  # @raise [ActiveRecord::RecordInvalid] the failing row, or the party with errors on :guide_effects
  def replace_solomonis_guide_effects!(entries)
    entries = entries.to_a.map { |e| e.to_h.symbolize_keys }
    effect_ids = entries.map { |e| e[:solomonis_guide_effect]&.id || e[:solomonis_guide_effect_id] }
    transaction do
      lock_solomonis_party!
      errors.clear
      errors.add(:guide_effects, 'are only for Evoking Solomonis parties') unless solomonis?
      errors.add(:guide_effects, 'list an effect more than once') if effect_ids.uniq.size != effect_ids.size
      errors.add(:guide_effects, 'can have only one inherited effect') if entries.count { |e| e[:inherited] } > 1
      raise ActiveRecord::RecordInvalid, self if errors.any?

      expedition_guide_effects.delete_all
      entries.each { |entry| expedition_guide_effects.create!(entry) }
    end
    expedition_guide_effects.reload
  end

  ##
  # Deletes the expedition, blessings and guidebook and clears the Solomonis
  # grid fields. Runs automatically when the raid leaves the Solomonis group.
  def clear_solomonis_data!
    @leaving_solomonis = false
    SolomonisExpedition.where(party_id: id).destroy_all
    PartyBlessing.where(party_id: id).delete_all
    ExpeditionGuideEffect.where(party_id: id).delete_all
    GridWeapon.where(party_id: id).update_all(seal_state: nil, unseal_priority: nil)
    GridSummon.where(party_id: id).update_all(seal_state: nil, unseal_priority: nil)
    GridCharacter.where(party_id: id).update_all(brought_by_blessing: false)
    association(:solomonis_expedition).reset
    party_blessings.reset
    expedition_guide_effects.reset
  end

  private

  # Takes the party's row lock for the rest of the transaction, so two
  # whole-list replaces on one party run one after the other instead of both
  # deleting and then both inserting. Doesn't reload, so unsaved attributes
  # and loaded associations stay as they are. Call inside a transaction.
  def lock_solomonis_party!
    self.class.where(id: id).lock.pick(:id) if persisted?
  end

  def apply_route_to_party(character)
    return unless character&.solomonis_route_eligible?

    self.raid_id = character.solomonis_zone_id
    self.element = character.element unless character.element.nil?
  end

  # Before validation: a new or changed route moves the party to the route's
  # zone and element. Otherwise a raid change out of the Solomonis group marks
  # the expedition for deletion.
  def sync_solomonis_route
    expedition = association(:solomonis_expedition).reader
    return unless expedition && !expedition.marked_for_destruction?

    if expedition.new_record? || expedition.route_evoker_id_changed?
      apply_route_to_party(expedition.route_evoker)
    elsif raid_id_changed? && !Raid.find_by(id: raid_id)&.solomonis_zone?
      expedition.mark_for_destruction
      @leaving_solomonis = true
    end
  end

  def solomonis_consistency
    if solomonis?
      expedition = solomonis_expedition
      evoker = expedition.route_evoker
      if evoker&.solomonis_route_eligible?
        errors.add(:raid, "must be the route Evoker's zone") if raid_id != evoker.solomonis_zone_id
        if !evoker.element.nil? && element != evoker.element
          errors.add(:element, "must match the route Evoker's element")
        end
      end
      validate_solomonis_character_count if expedition.new_record?
    elsif solomonis_zone?
      errors.add(:solomonis_expedition, 'with a route Evoker is required for an Evoking Solomonis zone')
    end
  end

  def validate_solomonis_character_count
    count = characters.count { |gc| !gc.marked_for_destruction? }
    limit = solomonis_character_limit
    return if count <= limit

    errors.add(:characters, "can be at most #{limit} on this Evoking Solomonis party")
  end

  def validate_blessing_loadout(levels)
    unless solomonis?
      errors.add(:blessings, 'are only for Evoking Solomonis parties')
      return
    end

    blessings = levels.map(&:arcarum_blessing)
    errors.add(:blessings, 'can hold one level of each blessing') if blessings.uniq.size != blessings.size
    errors.add(:blessings, 'must be released') unless blessings.all?(&:released?)
    total = levels.sum(&:cost)
    return if total <= ArcarumBlessing::COST_LIMIT

    errors.add(:blessings, "cost #{total}, over the limit of #{ArcarumBlessing::COST_LIMIT}")
  end

  def recompute_solomonis_state_after_expedition_change
    expedition = association(:solomonis_expedition).reader
    return unless expedition&.persisted? && !expedition.destroyed?
    return unless expedition.saved_change_to_id?

    recompute_solomonis_state!
  end

  def sync_solomonis_expedition_user
    SolomonisExpedition.where(party_id: id).update_all(user_id: user_id)
  end
end
