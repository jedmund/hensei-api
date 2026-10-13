# frozen_string_literal: true

module Processors
  ##
  # Imports an Evoking Solomonis run from the game's expedition report
  # (`kind: "solomonis_run"` on POST /import) into a new party, or into the
  # user's existing run for the same report.
  #
  # From the report: route Evoker (and so zone and element), class, the allies
  # at the end of the run, outcome (from bosses defeated), pledge level, end
  # time, turn count, stats and the default name. From the guidebook log: the
  # guidebook. From the optional `current_setup` (the route Evoker's party
  # deck, see Solomonis::PartyDeck): weapons, summons and blessings, every
  # weapon and summon unsealed (by the end of a run everything was).
  #
  # Imports keep what the game says: values that break Hensei's rules become
  # warnings (strings, unlike the deck processors' hashes) instead of failing.
  # Only a payload without a usable route Evoker or report ID raises ImportError.
  #
  # On re-import, what the user added on the web stays: the name and visibility
  # unless sent again, matching characters (and brought_by_blessing), each
  # guidebook effect's inherited flag, note and pickup order and, without a
  # current_setup, the weapons, summons, blessings, seal state and unseal
  # priority.
  class SolomonisProcessor < BaseProcessor
    class ImportError < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    CHARACTER_POSITIONS = (0..4).to_a.freeze
    # Character art suffix → the highest uncap level that shows it. The report
    # carries nothing better; the user's collection overrides it when linked.
    ART_UNCAP_LEVELS = { 1 => 3, 2 => 4, 3 => 5, 4 => 6 }.freeze
    MAX_REPORT_ID = (2**63) - 1

    # @param party [Party] a new party (unsaved) or the user's existing run
    # @param data [Hash] the request's `solomonis` object
    # @param options [Hash] `now:` the import time (for ended_at's year)
    def initialize(party, data, options = {})
      super
      @now = options[:now] || Time.current
    end

    # Reads the report's ID without touching the database, so the caller can
    # check for duplicates first.
    #
    # @return [Integer] the game's report ID
    # @raise [ImportError] when the payload has no usable report
    def self.report_id(data)
      report_id = data.is_a?(Hash) ? data['report_id'] : nil
      report_id = report_id.to_i if report_id.is_a?(String) && report_id.match?(/\A\d{1,19}\z/)
      unless report_id.is_a?(Integer) && report_id.between?(1, MAX_REPORT_ID)
        raise ImportError.new('invalid_data', 'solomonis.report_id must be a positive integer')
      end

      report_id
    end

    # Checks the payload's shape and size before any database work.
    #
    # @raise [ImportError]
    def self.validate!(data)
      report_id(data)
      unless data['report'].is_a?(Hash) && data['status_list'].is_a?(Array)
        raise ImportError.new('invalid_data', 'solomonis.report must be an object and status_list a list')
      end
      return if data['status_list'].size <= Solomonis::GuidebookImporter::MAX_ENTRIES

      raise ImportError.new('too_many_guide_effects',
                            "status_list can hold at most #{Solomonis::GuidebookImporter::MAX_ENTRIES} entries")
    end

    def process
      self.class.validate!(data)
      @report = Solomonis::ReportParser.new(data['report'], now: @now)

      assign_expedition
      assign_job
      save_party
      import_characters
      import_current_setup
      import_guidebook

      @warnings.concat(@report.warnings)
      party
    end

    private

    def report_id
      @report_id ||= self.class.report_id(data)
    end

    def assign_expedition
      evoker_id = @report.route_evoker_granblue_id
      evoker = evoker_id && Character.solomonis_route_evokers.find_by(granblue_id: evoker_id)
      raise ImportError.new('unknown_route_evoker', "The report's Evoker can't lead an expedition") unless evoker

      dungeon_report_id = @report.dungeon_report_id
      if dungeon_report_id && dungeon_report_id != report_id
        @warnings << "report_id #{report_id} doesn't match the report's own ID #{dungeon_report_id}"
      end

      expedition = party.assign_solomonis_route(evoker)
      expedition.assign_attributes(@report.expedition_attributes.merge(game_report_id: report_id))
      party.turn_count = @report.turn_count
      party.name = @report.deck_name if party.new_record? && party.name.blank?
      party.last_updated = Time.current
    end

    def assign_job
      job_id = @report.job_granblue_id
      job = job_id && Job.find_by(granblue_id: job_id)
      unless job
        @warnings << "Class #{job_id.to_s.truncate(20)} wasn't found; left empty" if job_id
        return
      end
      return if party.job_id == job.id

      party.job = job
      party.skill0 = JobSkill.find_by(job_id: job.id, main: true)
    end

    # The in-game party name is the default name, so a name the profanity
    # filter rejects is dropped rather than failing the import.
    def save_party
      if !party.valid? && party.errors.attribute_names == [:name]
        @warnings << "The party name wasn't accepted; left empty"
        party.name = nil
      end
      party.save!
    end

    #########################
    # Characters
    #########################

    # Keeps grid characters that are still in the report, removes the rest and
    # adds the missing ones in free slots.
    def import_characters
      wanted = @report.characters.filter_map { |entry| find_character(entry) }
      wanted_ids = wanted.map { |w| w[:character].granblue_id }

      current = party.characters.reject(&:is_substitute?)
      current.reject { |gc| wanted_ids.include?(gc.character.granblue_id) }.each(&:destroy!)
      kept_ids = current.select { |gc| wanted_ids.include?(gc.character.granblue_id) }.map { |gc| gc.character.granblue_id }
      party.characters.reset

      free = CHARACTER_POSITIONS - party.characters.reject(&:is_substitute?).map(&:position)
      wanted.reject { |w| kept_ids.include?(w[:character].granblue_id) }.each do |w|
        add_character(w, free.shift)
      end
    end

    def find_character(entry)
      evoker = party.solomonis_expedition.route_evoker
      character = (evoker if evoker.granblue_id == entry[:granblue_id]) ||
                  Character.find_by(granblue_id: entry[:granblue_id], style_swap: false) ||
                  Character.find_by(granblue_id: entry[:granblue_id])
      return { character: character, art: entry[:art].to_i } if character

      @warnings << "Character #{entry[:granblue_id]} wasn't found; skipped"
      nil
    end

    def add_character(wanted, position)
      character = wanted[:character]
      if position.nil?
        @warnings << "No room for #{character.name_en}; skipped"
        return
      end

      uncap = [ART_UNCAP_LEVELS.fetch(wanted[:art], 3), character.max_uncap_level].min
      grid_character = party.characters.build(
        character: character, position: position, uncap_level: uncap,
        transcendence_step: uncap > 5 ? 1 : 0,
        collection_character: party.user&.collection_characters&.find_by(character_id: character.id)
      )
      unless grid_character.save
        @warnings << "#{character.name_en} couldn't be added (#{grid_character.errors.full_messages.to_sentence})"
        discard_unsaved(grid_character, :characters)
        return
      end
      sync_collection(grid_character)
    end

    def sync_collection(grid_character)
      return unless grid_character.collection_character

      grid_character.sync_from_collection!
    rescue ActiveRecord::RecordInvalid => e
      log("Collection sync failed for #{grid_character.id}: #{e.record.errors.full_messages.join(', ')}")
      grid_character.reload
    end

    #########################
    # Weapons and summons
    #########################

    # The player's current setup for the same route Evoker, when captured. It
    # replaces the grid's weapons, summons and blessings; otherwise they stay
    # as they are.
    def import_current_setup
      setup = data['current_setup']
      return if setup.nil?

      unless Solomonis::PartyDeck.deck?(setup)
        @warnings << "current_setup isn't a party deck; weapons and summons weren't imported"
        return
      end

      deck = Solomonis::PartyDeck.new(setup)
      evoker = party.solomonis_expedition.route_evoker
      if deck.route_evoker_granblue_id != evoker.granblue_id
        @warnings << "current_setup is another Evoker's party; weapons and summons weren't imported"
        return
      end

      party.weapons.destroy_all
      party.summons.destroy_all
      import_blessings(deck)
      processors = [SummonProcessor.new(party, deck.body), WeaponProcessor.new(party, deck.body)]
      processors.each(&:process)
      processors.flat_map(&:warnings).each { |warning| @warnings << Solomonis::PartyDeck.warning_text(warning) }
      party.apply_solomonis_seal_states!(**deck.unsealed_seal_states)
    end

    def import_blessings(deck)
      levels = deck.blessing_levels
      @warnings.concat(deck.warnings)
      party.replace_solomonis_blessings!(levels)
    rescue ActiveRecord::RecordInvalid => e
      @warnings << "Blessings weren't imported (#{e.record.errors.full_messages.to_sentence})"
    end

    #########################
    # Guidebook
    #########################

    def import_guidebook
      importer = Solomonis::GuidebookImporter.new(data['status_list'])
      previous = party.expedition_guide_effects.index_by(&:solomonis_guide_effect_id)
      party.replace_solomonis_guide_effects!(importer.call(previous: previous))
      @warnings.concat(importer.warnings)

      claimed = @report.spacebook_status_count
      return if claimed.nil? || claimed == importer.stack_total

      @warnings << "spacebook_status_count is #{claimed} but the guidebook holds #{importer.stack_total} stacks"
    end
  end
end
