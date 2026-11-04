# frozen_string_literal: true

##
# Claims anonymous parties for a signed-in user with the edit keys the
# client kept for them, or with the keys the user deposited on the server.
#
# Each entry names a party by shortcode or id and resolves to one status:
# - migrated / ready: an anonymous party and its key; #claim! moves it to
#   the user, #preview only reports it;
# - already_claimed: a party with an owner that the user may view;
# - not_found: no such party, or someone else's party the user may not view,
#   so its existence isn't revealed (matching GET /parties/:shortcode);
# - invalid_key: an anonymous party with a wrong or missing key.
class PartyMigration
  MAX_ENTRIES = 100

  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  # What the :preview blueprint view renders.
  PREVIEW_INCLUDES = [
    { raid: :group }, :job,
    { characters: { character: :character_series_records } },
    { weapons: { weapon: %i[weapon_series weapon_series_variant] } },
    { summons: { summon: :summon_series } }
  ].freeze

  attr_reader :entries

  ##
  # @param user [User] the user claiming the parties
  # @param entries [Array<Hash>, nil] `shortcode` and `edit_key` pairs; nil
  #   uses the keys the user deposited
  # @param admin_mode [Boolean] whether an admin user is in admin mode
  def initialize(user, entries, admin_mode: false)
    @user = user
    @admin_mode = admin_mode
    @entries = entries || user.user_edit_keys.map { |uek| { shortcode: uek.shortcode, edit_key: uek.edit_key } }
  end

  # Whether there are more entries than one request may claim.
  def too_many?
    entries.size > MAX_ENTRIES
  end

  ##
  # Moves every anonymous party with a matching key to the user, clearing its
  # key, and drops the user's deposited keys for parties now theirs or
  # already claimed. All in one transaction.
  #
  # @return [Hash] results (shortcode and status per entry, in order) and
  #   migrated_count
  def claim!
    results = []

    ActiveRecord::Base.transaction do
      results = entries.map do |entry|
        shortcode = entry[:shortcode]
        { shortcode: shortcode, status: claim_entry(entry, find_party(shortcode)) }
      end

      claimed = results.select { |r| r[:status].in?(%w[migrated already_claimed]) }.pluck(:shortcode)
      @user.user_edit_keys.where(shortcode: claimed).delete_all if claimed.any?
    end

    { results: results, migrated_count: results.count { |r| r[:status] == 'migrated' } }
  end

  ##
  # What #claim! would do, changing nothing. A party named twice (by
  # shortcode and by id, say) is listed once.
  #
  # @return [Array<Hash>] party (loaded for the preview view, or nil when
  #   the user may not see it) and status, per distinct party
  def preview
    lookup = preview_lookup
    seen = Set.new

    entries.filter_map do |entry|
      party = lookup[entry[:shortcode]]
      next if party && !seen.add?(party.id)

      preview_entry(entry, party)
    end
  end

  private

  def claim_entry(entry, party)
    if party.nil?
      'not_found'
    elsif party.user_id.present?
      claimed_status(party)
    elsif !party.edit_key_matches?(entry[:edit_key])
      'invalid_key'
    else
      party.update!(user_id: @user.id, edit_key: nil)
      'migrated'
    end
  end

  def preview_entry(entry, party)
    if party.nil?
      { party: nil, status: 'not_found' }
    elsif party.user_id.present?
      status = claimed_status(party)
      { party: status == 'already_claimed' ? party : nil, status: status }
    elsif !party.edit_key_matches?(entry[:edit_key])
      { party: nil, status: 'invalid_key' }
    else
      { party: party, status: 'ready' }
    end
  end

  # A claimed party only confirms itself to users who can view it.
  def claimed_status(party)
    party.viewable_by?(@user, admin_mode: @admin_mode) ? 'already_claimed' : 'not_found'
  end

  def find_party(identifier)
    Party.find_by(shortcode: identifier) || Party.find_by(id: identifier)
  end

  # The entries' parties, keyed by both shortcode and id so either resolves.
  def preview_lookup
    identifiers = entries.pluck(:shortcode).uniq
    return {} if identifiers.empty?

    uuids = identifiers.grep(UUID_PATTERN)
    scope = Party.includes(*PREVIEW_INCLUDES)
    scope = scope.where(shortcode: identifiers)
    scope = scope.or(Party.includes(*PREVIEW_INCLUDES).where(id: uuids)) if uuids.any?

    scope.each_with_object({}) do |party, lookup|
      lookup[party.shortcode] = party
      lookup[party.id] = party
    end
  end
end
