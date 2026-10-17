# frozen_string_literal: true

module PartyParticipation
  ##
  # Computes participation scores for a set of parties. Each sticker counts
  # once, decayed by its age with the given half-life, and weighted by how
  # much we trust the giver. Remixes by other users and favorites by other
  # users add smaller, also decayed, contributions.
  #
  # Used for the stored `participation_score` (default half-life, no window)
  # and, at request time, for event sections (half-life tied to the event,
  # counting only activity inside the event's window).
  #
  # Returns { party_id => Float } for parties with any activity; parties
  # without activity are absent.
  class Scorer
    DEFAULT_HALF_LIFE = 7.days

    # Givers whose account was younger than this when they gave the sticker,
    # or who have no public parties, count for less.
    NEW_ACCOUNT_AGE = 14.days
    LOW_TRUST_WEIGHT = 0.25

    REMIX_WEIGHT = 0.3
    FAVORITE_WEIGHT = 0.15

    def self.call(party_ids, half_life: DEFAULT_HALF_LIFE, since: nil, as_of: Time.current)
      new(party_ids, half_life: half_life, since: since, as_of: as_of).call
    end

    # party_ids: an Array of ids or a relation selecting party ids.
    def initialize(party_ids, half_life:, since:, as_of:)
      @party_ids = party_ids
      @half_life = half_life.to_f
      @since = since
      @as_of = as_of
    end

    def call
      return {} if @party_ids.is_a?(Array) && @party_ids.empty?

      scores = Hash.new(0.0)
      sticker_scores.each { |id, value| scores[id] += value.to_f }
      remix_scores.each { |id, value| scores[id] += REMIX_WEIGHT * value.to_f }
      favorite_scores.each { |id, value| scores[id] += FAVORITE_WEIGHT * value.to_f }
      scores
    end

    private

    def sticker_scores
      trust = <<~SQL.squish
        CASE
          WHEN users.created_at <= party_stickers.created_at - make_interval(secs => #{NEW_ACCOUNT_AGE.to_i})
           AND EXISTS (SELECT 1 FROM parties gp WHERE gp.user_id = users.id AND gp.visibility = 1)
          THEN 1.0
          ELSE #{LOW_TRUST_WEIGHT}
        END
      SQL

      windowed(PartySticker.joins(:user).where(party_id: @party_ids), 'party_stickers.created_at')
        .group(:party_id)
        .sum(Arel.sql("#{decay('party_stickers.created_at')} * #{trust}"))
    end

    # Remixes made by someone other than the source party's owner. Anonymous
    # remixes don't count.
    def remix_scores
      remixes = Party.from('parties remixes')
                     .joins('INNER JOIN parties sources ON sources.id = remixes.source_party_id')
                     .where(remixes: { source_party_id: @party_ids })
                     .where('remixes.user_id IS NOT NULL AND remixes.user_id IS DISTINCT FROM sources.user_id')

      windowed(remixes, 'remixes.created_at')
        .group('remixes.source_party_id')
        .sum(Arel.sql(decay('remixes.created_at')))
    end

    # Favorites by someone other than the party's owner. Only the total is used.
    def favorite_scores
      favorites = Favorite.joins(:party)
                          .where(party_id: @party_ids)
                          .where('favorites.user_id IS DISTINCT FROM parties.user_id')

      windowed(favorites, 'favorites.created_at')
        .group('favorites.party_id')
        .sum(Arel.sql(decay('favorites.created_at')))
    end

    def windowed(scope, column)
      scope = scope.where("#{column} <= ?", @as_of)
      scope = scope.where("#{column} >= ?", @since) if @since
      scope
    end

    # 0.5 ^ (age / half-life), with age measured up to as_of.
    def decay(column)
      as_of = ActiveRecord::Base.connection.quote(@as_of.utc)
      "POWER(0.5, GREATEST(EXTRACT(EPOCH FROM (CAST(#{as_of} AS timestamp) - #{column})), 0) / #{@half_life})"
    end
  end
end
