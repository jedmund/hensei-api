# frozen_string_literal: true

module Processors
  ##
  # SummonProcessor processes an array of summon data and creates GridSummon records.
  # It handles different summon types based on the +type+ parameter:
  #   - :normal => standard summons
  #   - :friend => friend summon (fixed position and uncap logic)
  #   - :sub    => sub summons (position based on order)
  #
  # @example
  #   normal_processor = SummonProcessor.new(party, summons_array, :normal, quick_summon_id)
  #   normal_processor.process
  #
  #   friend_processor = SummonProcessor.new(party, [friend_summon_name], :friend)
  #   friend_processor.process
  class SummonProcessor < BaseProcessor
    TRANSCENDENCE_LEVELS = [200, 210, 220, 230, 240, 250].freeze

    ##
    # Initializes a new SummonProcessor.
    #
    # @param party [Party] the Party record.
    # @param data [Array<Hash>] an array of summon data hashes.
    # @param type [Symbol] the type of summon (:normal, :friend, or :sub).
    # @param quick_summon_id [String, nil] (optional) the quick summon identifier.
    # @param options [Hash] additional options.
    def initialize(party, data, type = :normal, options = {})
      super(party, data, options)
      @party = party
      @data = data
      @type = type
    end

    ##
    # Processes summon data and creates GridSummon records.
    #
    # @return [void]
    def process
      # Guard: ensure the data is in the expected format.
      unless @data.is_a?(Hash)
        Rails.logger.error "[SUMMON] Invalid data format: expected a Hash, got #{@data.class}"
        return
      end

      return unless @data.key?('summons') &&
        @data.key?('sub_summons') &&
        @data.key?('damage_info')

      @data = @data.with_indifferent_access if @data.is_a?(Hash)

      grid_summons = process_summons(@data['summons'], sub: false)
      friend_summon = process_friend_summon
      sub_summons = process_summons(@data['sub_summons'], sub: true)

      summons = [*grid_summons, friend_summon, *sub_summons]

      summons.each do |summon|
        summon.save!
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "[SUMMON] Failed to create GridSummon: #{e.record.errors.full_messages.join(', ')}"
      end
    end

    private

    attr_reader :type

    ##
    # Processes a set of summon data and creates GridSummon records.
    #
    # @param summons [Hash] the summon data
    # @param sub [Boolean] true if we are polling sub summons
    # @return [Array<GridSummon>]
    def process_summons(summons, sub: false)
      internal_quick_summon_id = @data['quick_user_summon_id'].to_i if sub

      summons.map do |key, raw_summon|
        summon_params = raw_summon['param']
        summon_id = raw_summon['master']['id']
        summon = Summon.find_by(granblue_id: transform_id(summon_id))

        position = if sub
                     key.to_i + 4
                   else
                     key.to_i == 1 ? -1 : key.to_i - 2
                   end

        GridSummon.new({
                         party: @party,
                         summon: summon,
                         position: position,
                         main: key.to_i == 1,
                         friend: false,
                         quick_summon: summon_params['id'].to_i == internal_quick_summon_id,
                         uncap_level: summon_params['evolution'].to_i,
                         transcendence_step: level_to_transcendence(summon_params['level'].to_i),
                         created_at: Time.now,
                         updated_at: Time.now
                       })
      end
    end

    ##
    # Processes friend summon data and creates a GridSummon record.
    #
    # @return [GridSummon]
    def process_friend_summon
      summon_name = @data['damage_info']['summon_name']
      summon = Summon.find_by('name_en = ? OR name_jp = ?', summon_name, summon_name)

      GridSummon.new({
                       party: @party,
                       summon: summon,
                       position: 4,
                       main: false,
                       friend: true,
                       quick_summon: false,
                       uncap_level: determine_uncap_level(summon),
                       transcendence_step: summon.transcendence ? 5 : 0,
                       created_at: Time.now,
                       updated_at: Time.now
                     })
    end

    ##
    # Determines the numeric uncap level of a given Summon
    #
    # @param summon [Summon] the canonical summon
    # @return [Integer]
    def determine_uncap_level(summon)
      if summon.transcendence
        6
      elsif summon.ulb
        5
      elsif summon.flb
        4
      else
        3
      end
    end

    ##
    # Determines the uncap level for a friend summon based on its ULb and FLb flags.
    #
    # @param summon_data [Hash] the summon data.
    # @return [Integer] the computed uncap level.
    def determine_friend_uncap(summon_data)
      if summon_data[:ulb]
        5
      elsif summon_data[:flb]
        4
      else
        3
      end
    end

    ##
    # Converts a given level, rounded down to the nearest 10,
    # to its corresponding transcendence step.
    #
    # If level is 200, returns 0; if level is 250, returns 5.
    #
    # @param level [Integer] the summon's level
    # @return [Integer] the transcendence step
    def level_to_transcendence(level)
      return 0 if level < 200

      floored_level = (level / 10).floor * 10
      TRANSCENDENCE_LEVELS.index(floored_level)
    end

    ##
    # Transforms 5★ Arcarum-series summon IDs into their 4★ variants,
    # as that's what is stored in the database.
    #
    # If an unrelated ID, or the 4★ ID is passed, then returns the input.
    #
    # @param id [String] the ID to match
    # @return [String] the resulting ID
    def transform_id(id)
      mapping = {
        '2040315000' => '2040238000',
        '2040316000' => '2040239000',
        '2040314000' => '2040237000',
        '2040313000' => '2040236000',
        '2040321000' => '2040244000',
        '2040319000' => '2040242000',
        '2040317000' => '2040240000',
        '2040322000' => '2040245000',
        '2040318000' => '2040241000',
        '2040320000' => '2040243000'
      }

      # If the id is a key, return the mapped value; otherwise, return the id.
      mapping[id] || id
    end
  end
end
