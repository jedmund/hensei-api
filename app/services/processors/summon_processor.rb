# frozen_string_literal: true

module Processors
  ##
  # SummonProcessor builds GridSummon records from a deck: the main grid
  # summons, the friend summon (position 6, at its max uncap) and the sub
  # summons (positions 4 and 5).
  #
  # @example
  #   processor = Processors::SummonProcessor.new(party, deck_data)
  #   processor.process
  class SummonProcessor < GridItemProcessor
    grid_item :summon, deck_path: %w[deck pc], association: :summons

    private

    def build_items
      pc = @data.dig('deck', 'pc')
      [*build_summons(pc['summons'], sub: false), build_friend_summon, *build_summons(pc['sub_summons'], sub: true)].compact
    end

    ##
    # Builds the main grid or sub summons.
    #
    # @param summons [Hash] the summon data, keyed by slot
    # @param sub [Boolean] true for the sub summons
    # @return [Array<GridSummon>]
    def build_summons(summons, sub:)
      # Only main-grid summons can be quick summons.
      quick_id = sub ? nil : quick_summon_id
      summons.filter_map { |key, raw_summon| build_summon(key.to_i, raw_summon, sub:, quick_id:) }
    end

    # The deck's quick summon, or nil: a missing or zero id never matches, so a
    # deck without a quick summon (or summons without ids) marks none.
    def quick_summon_id
      id = @data.dig('deck', 'pc', 'quick_user_summon_id').to_i
      id if id.positive?
    end

    def build_summon(slot, raw_summon, sub:, quick_id:)
      return if incomplete?(raw_summon)

      param = raw_summon['param']
      summon = find_summon(raw_summon['master']['id'])
      return unless summon

      grid_summon = new_grid_summon(
        summon,
        position: summon_position(slot, sub),
        main: !sub && slot == 1,
        friend: false,
        quick_summon: !quick_id.nil? && param['id'].to_i == quick_id,
        uncap_level: param['evolution'].to_i,
        transcendence_step: level_to_transcendence(param['level'].to_i)
      )
      link_collection_summon(grid_summon, param['id'])
      grid_summon
    end

    # Slot 1 is the main summon (-1), the others follow from 0; sub summons sit after the grid.
    def summon_position(slot, sub)
      return slot + 3 if sub

      slot == 1 ? -1 : slot - 2
    end

    def find_summon(game_id)
      summon = Summon.find_by(granblue_id: SummonIdMapping.resolve(game_id))
      log_error "Summon not found with id #{game_id}" unless summon
      summon
    end

    def build_friend_summon
      summon_name = @data.dig('deck', 'pc', 'damage_info', 'summon_name')
      summon = Summon.find_by('name_en = ? OR name_jp = ?', summon_name, summon_name)

      unless summon
        log_error "Friend summon not found: #{summon_name}"
        return nil
      end

      new_grid_summon(summon, position: GridSummon::FRIEND_POSITION, main: false, friend: true, quick_summon: false,
                              uncap_level: summon.max_uncap_level, transcendence_step: summon.max_transcendence_step)
    end

    def new_grid_summon(summon, **attrs)
      GridSummon.new(party: @party, summon: summon, **attrs, created_at: Time.current, updated_at: Time.current)
    end

    # Links to the collection summon with the game's copy id, creating one when the
    # user imports to their collection. A summon without an id isn't linked.
    def link_collection_summon(grid_summon, game_id)
      return if game_id.blank?

      link_collection(grid_summon, { game_id: game_id.to_s },
                      summon_id: grid_summon.summon_id,
                      uncap_level: grid_summon.uncap_level,
                      transcendence_step: grid_summon.transcendence_step)
    end
  end
end
