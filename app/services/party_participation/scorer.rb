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

    # Built from Arel nodes rather than SQL strings, so no value is ever
    # interpolated into a query.
    def sticker_scores
      stickers = PartySticker.arel_table
      windowed(PartySticker.joins(:user).where(party_id: @party_ids), stickers[:created_at])
        .group(:party_id)
        .sum(Arel::Nodes::Multiplication.new(decay(stickers[:created_at]), trust(stickers[:created_at])))
    end

    # Remixes made by someone other than the source party's owner. Anonymous
    # remixes don't count.
    def remix_scores
      remixes = Party.from('parties remixes')
                     .joins('INNER JOIN parties sources ON sources.id = remixes.source_party_id')
                     .where(remixes: { source_party_id: @party_ids })
                     .where('remixes.user_id IS NOT NULL AND remixes.user_id IS DISTINCT FROM sources.user_id')
      created_at = Arel::Table.new(:remixes)[:created_at]

      windowed(remixes, created_at)
        .group('remixes.source_party_id')
        .sum(decay(created_at))
    end

    # Favorites by someone other than the party's owner. Only the total is used.
    def favorite_scores
      favorites = Favorite.joins(:party)
                          .where(party_id: @party_ids)
                          .where('favorites.user_id IS DISTINCT FROM parties.user_id')
      created_at = Favorite.arel_table[:created_at]

      windowed(favorites, created_at)
        .group('favorites.party_id')
        .sum(decay(created_at))
    end

    def windowed(scope, created_at)
      scope = scope.where(created_at.lteq(@as_of))
      scope = scope.where(created_at.gteq(@since)) if @since
      scope
    end

    # 0.5 ^ (age / half-life), with age in seconds measured up to as_of.
    def decay(created_at)
      as_of = function('CAST', Arel::Nodes::As.new(quoted(@as_of.utc), Arel.sql('timestamp')))
      age = Arel::Nodes::Subtraction.new(as_of, created_at)
      seconds = function('date_part', 'epoch', age)
      function('POWER', 0.5, Arel::Nodes::Division.new(function('GREATEST', seconds, 0), quoted(@half_life)))
    end

    # 1 for a giver whose account was at least NEW_ACCOUNT_AGE old when they
    # gave the sticker and who has a public party; LOW_TRUST_WEIGHT otherwise.
    def trust(given_at)
      users = User.arel_table
      settled = users[:created_at].lteq(
        Arel::Nodes::Subtraction.new(given_at, function('make_interval', 0, 0, 0, 0, 0, 0, NEW_ACCOUNT_AGE.to_i))
      )
      public_party = Party.from('parties gp').where('gp.user_id = users.id AND gp.visibility = 1').select(1).arel.exists

      Arel::Nodes::Case.new.when(settled.and(public_party)).then(quoted(1.0)).else(quoted(LOW_TRUST_WEIGHT))
    end

    def function(name, *args)
      Arel::Nodes::NamedFunction.new(name, args.map { |arg| quoted(arg) })
    end

    # A value as an Arel node, quoted by the connection
    def quoted(value)
      Arel::Nodes.build_quoted(value)
    end
  end
end
