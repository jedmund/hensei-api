# frozen_string_literal: true

##
# How the Gallery and Home pick and order teams: the default quality bar
# (`.quality`) and the Rising rank (`.rising`, `.rising_rank_sql`).
module Party::Ranking
  extend ActiveSupport::Concern

  # The Gallery's default quality bar, shared with Home's cards. A team needs
  # at least this many weapons and summons…
  QUALITY_MIN_WEAPONS = 5
  QUALITY_MIN_SUMMONS = 2
  # …and a name other than a default one: Untitled/無題, "New Team" (what the
  # web app names new teams), and up to five remixes of each. Lowercase,
  # since names are compared case-insensitively.
  LOW_QUALITY_NAMES = ['untitled', '無題', 'new team'].flat_map do |name|
    (0..5).flat_map { |n| ["#{'remix of ' * n}#{name}", "#{name}#{'のリミックス' * n}"] }
  end.uniq.freeze

  # A team's Rising rank halves for every this much of its age, so new teams
  # rank well above older ones with the same score
  RISING_AGE_HALF_LIFE = 14.days

  included do
    ##
    # Teams that meet the Gallery's default quality bar: an owner, a name that
    # isn't a default, and the minimum weapons and summons. Evoking Solomonis
    # teams are exempt from the minimums, since they start with three weapons
    # and one summon and unlock more during a run.
    scope :quality, lambda {
      filled = where(weapons_count: QUALITY_MIN_WEAPONS.., summons_count: QUALITY_MIN_SUMMONS..)
      where.not(user_id: nil)
           .where(quality_name_sql)
           .merge(filled.or(where(raid_id: Raid.solomonis_zones.select(:id))))
    }

    ##
    # Rising: public teams with a participation score (which already decays
    # with the age of each sticker, remix and favorite), ranked by that score
    # discounted by the team's own age, then by id. Shared by Home's Rising
    # card and the Gallery's `sort=rising`, so the two always agree.
    #
    # @param now [Time] the time team ages are measured from.
    scope :rising, lambda { |now: Time.current|
      where(visibility: 1).where('parties.participation_score > 0')
                          .order(Arel.sql(rising_rank_sql(now)), id: :asc)
    }
  end

  class_methods do
    # SQL condition: the team's name isn't a default one (NULL names fail it).
    def quality_name_sql
      "LOWER(parties.name) NOT IN (#{LOW_QUALITY_NAMES.map { |name| connection.quote(name) }.join(',')})"
    end

    # SQL ORDER BY term for the Rising rank, measuring ages from `now`.
    def rising_rank_sql(now)
      sanitize_sql_array(
        [
          'parties.participation_score * POWER(0.5, ' \
          'GREATEST(EXTRACT(EPOCH FROM (? - parties.created_at)), 0) / ?) DESC',
          now, RISING_AGE_HALF_LIFE.to_i
        ]
      )
    end
  end
end
