# frozen_string_literal: true

module Solomonis
  ##
  # Reads an Evoking Solomonis expedition report (the `option` of
  # GET /arcarum3/dungeon/report/content/detail/<id>, without langMsg) into
  # plain values. Doesn't touch the database.
  #
  # The game is the source of truth, so values that break Hensei's rules are
  # dropped with a warning instead of failing the import. Only a missing route
  # Evoker ID is fatal (nothing else can be placed without it); the caller
  # decides what to do with #route_evoker_granblue_id being nil.
  class ReportParser
    # Report count fields → SolomonisExpedition stats keys.
    STATS_FIELDS = {
      'normal_enemy_count' => 'battle',
      'strong_enemy_count' => 'strong',
      'super_strong_enemy_count' => 'terrifying',
      'guardian_count' => 'ruler',
      'boss_count' => 'boss',
      'incident_count' => 'event',
      'recovery_count' => 'healing',
      'treasure_chest_count' => 'chest',
      'warp_count' => 'teleporter',
      'special_count' => 'special',
      'shop_purchase_count' => 'shop_purchases',
      'total_dungeon_point' => 'points_earned'
    }.freeze
    CHARACTER_FIELDS = %w[npc1_image_id npc2_image_id npc3_image_id npc4_image_id npc5_image_id].freeze
    MAX_INT = (2**31) - 1
    NAME_MAX_LENGTH = 100
    # ended_at carries no year: take the most recent such date not after now,
    # with some slack for clocks that run ahead.
    ENDED_AT_SKEW = 1.hour
    ENDED_AT_YEARS_BACK = 8
    TIME_ZONE = 'Asia/Tokyo'

    attr_reader :warnings

    # @param report [Hash] the report `option`
    # @param now [Time] the time of import, for the year of ended_at
    def initialize(report, now: Time.current)
      @report = report
      @now = now
      @warnings = []
    end

    # @return [String, nil] the route Evoker's granblue_id, from thumbnail_image
    def route_evoker_granblue_id
      image_granblue_id(@report['thumbnail_image'])
    end

    # @return [String, nil] the class's granblue_id, from pc_image_id
    def job_granblue_id
      image_granblue_id(@report['pc_image_id'])
    end

    # The allies at the end of the run (route Evoker included), in report
    # order, without repeats. Order carries no meaning in this mode.
    #
    # @return [Array<Hash>] `{ granblue_id:, art: }`
    def characters
      found = CHARACTER_FIELDS.filter_map do |field|
        value = @report[field]
        next if value.blank?

        match = value.is_a?(String) && value.match(/\A(\d{1,20})_(\d{1,3})/)
        unless match
          @warnings << "#{field} isn't a character image ID; skipped"
          next
        end
        { granblue_id: match[1], art: match[2] }
      end
      found.uniq { |c| c[:granblue_id] }
    end

    # @return [Hash] SolomonisExpedition attributes (the expedition's result and pledge)
    def expedition_attributes
      {
        pledge_level: parse_pledge_level,
        outcome: parse_outcome,
        ended_at: parse_ended_at,
        stats: parse_stats
      }
    end

    # @return [Integer, nil] Party#turn_count, from total_turn
    def turn_count
      parse_count('total_turn')
    end

    # @return [String, nil] the in-game party name, for the default name
    def deck_name
      name = @report['deck_name']
      return nil unless name.is_a?(String)

      name.squish.truncate(NAME_MAX_LENGTH, omission: '').presence
    end

    # @return [Integer, nil] the total guidebook stacks the report claims
    def spacebook_status_count
      parse_count('spacebook_status_count', warn: false)
    end

    # @return [Integer, nil] the report's own ID, to compare with the request's report_id
    def dungeon_report_id
      parse_count('dungeon_report_id', warn: false)
    end

    private

    def image_granblue_id(value)
      return nil unless value.is_a?(String)

      value[/\A(\d{1,20})_/, 1]
    end

    def parse_pledge_level
      value = parse_count('difficulty')
      return 0 if value.nil?
      return value if SolomonisExpedition::PLEDGE_LEVELS.cover?(value)

      @warnings << "difficulty #{value} isn't a pledge level (0–5); saved as 0"
      0
    end

    # Bosses defeated decide the outcome (0 Miasma 1, 1 Miasma 2, 2 cleared).
    # is_success only cross-checks it: when it disagrees, boss_count wins.
    def parse_outcome
      bosses = parse_count('boss_count', warn: false) # the stats warn about an unreadable count
      outcome = bosses && SolomonisExpedition.outcome_for_bosses(bosses)
      unless outcome
        if bosses
          @warnings << "boss_count #{bosses} is out of range; outcome left empty"
        elsif @report['boss_count'].nil?
          @warnings << 'boss_count is missing; outcome left empty'
        end
        return nil
      end

      success = parse_success
      if !success.nil? && success != (outcome == 'cleared')
        @warnings << "is_success is #{success} but boss_count is #{bosses}; outcome follows boss_count"
      end
      outcome
    end

    def parse_success
      case @report['is_success']
      when true, 1, '1', 'true' then true
      when false, 0, '0', 'false' then false
      end
    end

    def parse_stats
      STATS_FIELDS.each_with_object({}) do |(field, key), stats|
        value = parse_count(field)
        stats[key] = value unless value.nil?
      end
    end

    # "10/11 16:38" in JST, no year.
    def parse_ended_at
      raw = @report['ended_at']
      return nil if raw.nil?

      match = raw.is_a?(String) && raw.strip.match(%r{\A(\d{1,2})/(\d{1,2}) (\d{1,2}):(\d{2})\z})
      time = match && resolve_year(*match.captures.map(&:to_i))
      @warnings << "ended_at #{raw.to_s.truncate(40).inspect} isn't a date; left empty" unless time
      time
    end

    def resolve_year(month, day, hour, minute)
      return nil unless hour.between?(0, 23) && minute.between?(0, 59)

      zone = Time.find_zone!(TIME_ZONE)
      latest = @now + ENDED_AT_SKEW
      year = @now.in_time_zone(zone).year
      ENDED_AT_YEARS_BACK.times do |back|
        candidate_year = year - back
        next unless Date.valid_date?(candidate_year, month, day)

        time = zone.local(candidate_year, month, day, hour, minute)
        return time if time <= latest
      end
      nil
    end

    # Count fields arrive as strings ("14") or integers.
    def parse_count(field, warn: true)
      value = @report[field]
      return nil if value.nil?

      int = case value
            when Integer then value
            when /\A\d{1,10}\z/ then value.to_i
            end
      return int if int&.between?(0, MAX_INT)

      @warnings << "#{field} isn't a count; ignored" if warn
      nil
    end
  end
end
