# frozen_string_literal: true

module PartyViews
  ##
  # Counts unique viewers of a party per UTC day in Redis. Page views never
  # touch Postgres: FlushJob copies the day's counts into party_view_days.
  #
  # A viewer is `u:<user id>` when signed in, otherwise a hash of their IP with
  # a random salt made for that day. The salt lives only in Redis and expires
  # with the day's sets, so the hashes can't be reversed or linked across days.
  # The IP itself is never stored.
  #
  # Keys (all expire after TTL):
  #   <prefix>:salt:<date>          the day's salt
  #   <prefix>:seen:<date>:<party>  set of viewer ids
  #   <prefix>:parties:<date>       set of parties viewed that day
  module Recorder
    PREFIX = 'party_views'
    TTL = 2.days.to_i

    module_function

    # Records a view of party_id by user (or, signed out, ip). Returns true
    # when it was the viewer's first view of the party that day.
    def record(party_id:, user: nil, ip: nil, now: Time.current)
      date = now.utc.to_date.iso8601
      Sidekiq.redis do |redis|
        viewer = user ? "u:#{user.id}" : anonymous_id(redis, ip, date)
        next false unless viewer

        seen_key = "#{PREFIX}:seen:#{date}:#{party_id}"
        added = redis.call('SADD', seen_key, viewer).to_i.positive?
        redis.call('EXPIRE', seen_key, TTL)
        if added
          parties_key = "#{PREFIX}:parties:#{date}"
          redis.call('SADD', parties_key, party_id)
          redis.call('EXPIRE', parties_key, TTL)
        end
        added
      end
    end

    # { party_id => unique viewers } for a UTC date.
    def counts(date)
      Sidekiq.redis do |redis|
        party_ids = redis.call('SMEMBERS', "#{PREFIX}:parties:#{date.iso8601}")
        party_ids.index_with { |id| redis.call('SCARD', "#{PREFIX}:seen:#{date.iso8601}:#{id}").to_i }
      end
    end

    def anonymous_id(redis, ip, date)
      return nil if ip.blank?

      "a:#{OpenSSL::HMAC.hexdigest('SHA256', daily_salt(redis, date), ip.to_s)[0, 32]}"
    end

    def daily_salt(redis, date)
      key = "#{PREFIX}:salt:#{date}"
      redis.call('SET', key, SecureRandom.hex(32), 'NX', 'EX', TTL)
      redis.call('GET', key)
    end
  end
end
