# frozen_string_literal: true

class Dataminer
  ##
  # Stores a game payload as its catalogue row's game_raw_* source (D35) and
  # records the outcome (fetched, skipped or error) on the run's summary.
  #
  # Characters: style 2 is the style_swap row, anything else the base row. The
  # response's own style wins over the requested one when they disagree, so a
  # payload never lands on the other style's row.
  class PayloadStore
    # What a log line names: "Character 3040001000 (style 2)".
    Target = Data.define(:model_name, :granblue_id, :style_note)

    # @param summary [Granblue::SourceFetchSummary]
    # @param logger [Logger]
    def initialize(summary:, logger:)
      @summary = summary
      @logger = logger
    end

    ##
    # @param model_name [String] 'Character', 'Weapon' or 'Summon'
    # @param granblue_id [String]
    # @param payload [Object] the parsed game response; anything but a Hash is ignored
    # @param style [Integer] the character style requested
    # @param lang [String] picks game_raw_en or game_raw_jp
    # @return [void]
    def store(model_name, granblue_id, payload, style: 1, lang: 'en')
      return unless payload.is_a?(Hash)

      character = model_name == 'Character'
      column = column_for(character, granblue_id, payload, lang)
      return if character && skipped_character?(granblue_id, payload, style)

      target = Target.new(model_name, granblue_id, (" (style #{style})" if character))
      record = find_record(model_name, granblue_id, character, style)
      record ? write(record, column, payload, target) : not_found(target)
    rescue StandardError => e
      @summary.error!(granblue_id, e.message)
      @logger.error "Error updating #{model_name} #{granblue_id}: #{e.message}"
    end

    private

    # The game answers in the session's language: a character payload is stored by its own.
    def column_for(character, granblue_id, payload, lang)
      column = LANG_COLUMNS.fetch(lang.to_s) { raise ArgumentError, "unknown lang #{lang.inspect}" }
      detected = character && Granblue::GamePayload.language(payload)
      return column unless detected && LANG_COLUMNS[detected] != column

      @logger.info "Character #{granblue_id}: asked for #{column}, payload reads as #{detected}; stored as #{detected}"
      LANG_COLUMNS[detected]
    end

    # Error and popup responses are hashes too; only a character payload of a
    # style with a row is stored.
    def skipped_character?(granblue_id, payload, style)
      reason, note = character_skip(payload, style.to_i)
      return false unless reason

      @summary.skipped!(reason)
      @logger.warn "Character #{granblue_id}: #{note}; not stored"
      true
    end

    def character_skip(payload, style)
      unless Granblue::GamePayload.granblue_id(payload).present? && payload['ability'].present?
        return ['no character payload', 'response has no id or ability']
      end

      response_style = Granblue::GamePayload.style(payload).presence&.to_i
      return ['style mismatch', "asked for style #{style}, got #{response_style}"] if response_style && response_style != style
      return ['no row for style', "no row for style #{style}"] unless [1, 2].include?(style)

      nil
    end

    def find_record(model_name, granblue_id, character, style)
      model = Object.const_get(model_name)
      return model.find_by(granblue_id: granblue_id) unless character

      model.find_by(granblue_id: granblue_id, style_swap: style.to_i == 2)
    end

    # The payload is compared by sha256 without loading it.
    def write(record, column, payload, target)
      before = record.source_sha256(column)
      unless record.update(column => payload, "#{column}_fetched_at": Time.current)
        @summary.error!(target.granblue_id, record.errors.full_messages.to_sentence)
        return
      end

      @summary.fetched!(target.granblue_id, before: before, after: record.source_sha256(column))
      @logger.debug "Updated #{target.model_name} #{target.granblue_id} #{column}#{target.style_note}"
    end

    def not_found(target)
      @summary.skipped!('not in database')
      @logger.warn "#{target.model_name} with granblue_id #{target.granblue_id}#{target.style_note} not found in database"
    end
  end
end
