# frozen_string_literal: true

##
# Copies an account's active, battle-relevant Wonders onto a new team, as
# they are now. Runs from Party's after_create, so it covers parties#create,
# the imports and the wiki import.
#
# The account is the party's collection source when it has one (the team is
# being built for that account), else its owner. Anonymous teams get nothing.
# Remixes are skipped: amoeba copies the source team's party_wonders.
# Element isn't filtered, since teams often change element after creation.
#
# A failure here never fails the party create; it's logged and the team
# starts without Wonders.
class PartyWonderSnapshot
  COPIED_FIELDS = %w[wonder_id level evolution possession image].freeze

  def initialize(party)
    @party = party
  end

  def call
    return if @party.source_party_id.present? || @party.remix
    return if @party.party_wonders.any?

    user = @party.collection_source_user || @party.user
    return unless user

    rows = snapshot_rows(user)
    return if rows.empty?

    PartyWonder.transaction(requires_new: true) { PartyWonder.insert_all!(rows) }
    @party.party_wonders.reset
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn("[PartyWonderSnapshot] party=#{@party.id} skipped: #{e.class}: #{e.message}")
  end

  private

  def snapshot_rows(user)
    user.collection_wonders.active
        .joins(:wonder).where(wonders: { battle_relevant: true })
        .pluck(*COPIED_FIELDS.map { |field| "collection_wonders.#{field}" })
        .map { |values| COPIED_FIELDS.zip(values).to_h.merge('party_id' => @party.id) }
  end
end
