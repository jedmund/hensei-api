# frozen_string_literal: true

##
# The Evoking Solomonis side of a party (1:1): a build (a starting party
# people can copy) or a run (a finished expedition).
#
# The route Evoker decides the party's zone (raid) and element. Change it
# through the party (`party.assign_solomonis_route(character)` or nested
# `solomonis_expedition_attributes`), which keeps raid and element in step;
# saving a route change on the expedition alone fails validation when the
# party's raid or element no longer match.
#
# user_id is copied from the party so a game report can be imported once per user.
class SolomonisExpedition < ApplicationRecord
  KINDS = %w[build run].freeze
  OUTCOMES = %w[cleared failed].freeze
  MIDBOSSES = %w[banes_gate infernobringer beast_of_anathema].freeze
  PLEDGE_LEVELS = (0..5)
  MAX_BOSSES = 2
  STATS_KEYS = %w[battle strong terrifying ruler boss event healing chest teleporter special
                  shop_purchases points_earned].freeze
  # Fields that describe one expedition: empty on builds, cleared on remix.
  RUN_ONLY_FIELDS = %i[outcome bosses_defeated midboss expedition_level build_party_id game_report_id
                       ended_at].freeze

  belongs_to :party, inverse_of: :solomonis_expedition
  belongs_to :user, optional: true
  belongs_to :route_evoker, class_name: 'Character'
  belongs_to :build_party, class_name: 'Party', optional: true

  amoeba do
    RUN_ONLY_FIELDS.each { |field| nullify field }
    customize(->(_original, copy) { copy.stats = {} })
  end

  before_validation :copy_user_from_party
  before_validation :normalize_stats

  validates :party_id, uniqueness: true, allow_nil: true
  validates :kind, inclusion: { in: KINDS }
  validates :pledge_level, numericality: { only_integer: true }, inclusion: { in: PLEDGE_LEVELS }
  validates :outcome, inclusion: { in: OUTCOMES }, allow_nil: true
  validates :bosses_defeated, numericality: { only_integer: true }, inclusion: { in: 0..MAX_BOSSES }, allow_nil: true
  validates :midboss, inclusion: { in: MIDBOSSES }, allow_nil: true
  validates :expedition_level, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :game_report_id, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :game_report_id, uniqueness: { scope: :user_id }, allow_nil: true, if: :user_id?

  validate :route_evoker_eligible
  validate :route_matches_party
  validate :build_has_no_run_fields
  validate :cleared_run_defeated_all_bosses
  validate :stats_shape
  validate :build_party_is_solomonis_build

  scope :builds, -> { where(kind: 'build') }
  scope :runs, -> { where(kind: 'run') }

  def build?
    kind == 'build'
  end

  def run?
    kind == 'run'
  end

  def zone
    route_evoker&.solomonis_zone
  end

  private

  def copy_user_from_party
    self.user_id = party&.user_id
  end

  def normalize_stats
    self.stats = {} if stats.nil?
  end

  def route_evoker_eligible
    return unless route_evoker
    return if route_evoker.solomonis_route_eligible?

    errors.add(:route_evoker, 'must be an Evoker that can lead an Evoking Solomonis expedition')
  end

  def route_matches_party
    return unless party && route_evoker&.solomonis_route_eligible?

    errors.add(:route_evoker, "must belong to the party's zone") if party.raid_id != route_evoker.solomonis_zone_id
    return if route_evoker.element.nil? || party.element == route_evoker.element

    errors.add(:route_evoker, "must match the party's element")
  end

  def build_has_no_run_fields
    return unless build?

    RUN_ONLY_FIELDS.each do |field|
      errors.add(field, 'must be empty on a build') unless self[field].nil?
    end
    errors.add(:stats, 'must be empty on a build') if stats.present?
    return unless party&.persisted? && party.expedition_guide_effects.exists?

    errors.add(:kind, 'cannot be build while the party has a guidebook')
  end

  def cleared_run_defeated_all_bosses
    return unless outcome == 'cleared' && !bosses_defeated.nil? && bosses_defeated != MAX_BOSSES

    errors.add(:bosses_defeated, "must be #{MAX_BOSSES} on a cleared run")
  end

  def stats_shape
    unless stats.is_a?(Hash)
      errors.add(:stats, 'must be an object')
      return
    end

    unknown = stats.keys.map(&:to_s) - STATS_KEYS
    errors.add(:stats, "has unknown keys: #{unknown.join(', ')}") if unknown.any?
    return if stats.values.all? { |v| v.is_a?(Integer) && !v.negative? }

    errors.add(:stats, 'values must be non-negative integers')
  end

  # Viewability depends on who is asking, so the endpoint checks that the
  # build is visible to the current user. Here: it is a Solomonis build, and
  # not this party.
  def build_party_is_solomonis_build
    return if build_party_id.nil?

    if build_party_id == party_id
      errors.add(:build_party, 'cannot be the party itself')
    elsif !build_party&.solomonis_expedition&.build?
      errors.add(:build_party, 'must be an Evoking Solomonis build')
    end
  end
end
