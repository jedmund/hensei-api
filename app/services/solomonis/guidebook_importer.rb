# frozen_string_literal: true

module Solomonis
  ##
  # Turns a guidebook log's `status_list` into guidebook entries for
  # Party#replace_solomonis_guide_effects!, matching effects by `status_id`.
  #
  # Imports never write to the catalogue, which is shared by everyone and
  # seeded from game captures: an effect it doesn't have is skipped with a
  # warning. The entry's text only supplies the run's {value}.
  #
  # Everything here is client-supplied, so entries are checked field by field;
  # malformed ones are skipped with a warning. Call #validate_size! first.
  class GuidebookImporter
    class TooManyEntries < StandardError; end

    MAX_ENTRIES = 300
    MAX_COUNT = 999
    MAX_ID = (2**31) - 1
    LINE_BREAK = '@@'
    VALUE_PLACEHOLDER = '{value}'
    JAPANESE_SCRIPT = /[\p{Hiragana}\p{Katakana}\p{Han}]/

    attr_reader :warnings

    # @param status_list [Array<Hash>]
    def initialize(status_list)
      @status_list = status_list
      @warnings = []
    end

    def self.validate_size!(status_list)
      raise TooManyEntries if status_list.size > MAX_ENTRIES
    end

    # Sum of `num` over well-formed counts, to check against the report's
    # spacebook_status_count.
    def stack_total
      @status_list.sum do |entry|
        entry.is_a?(Hash) && valid_status_id?(entry['status_id']) && valid_count?(entry['num']) ? entry['num'].to_i : 0
      end
    end

    # @param previous [Hash{String => ExpeditionGuideEffect}] the run's current
    #   rows by effect ID, whose hand-entered fields carry over on re-import
    # @return [Array<Hash>] entries for Party#replace_solomonis_guide_effects!
    def call(previous: {})
      self.class.validate_size!(@status_list)
      entries = @status_list.each_with_index.filter_map { |raw, index| read_entry(raw, index) }
      entries = drop_repeats(entries)
      catalogue = SolomonisGuideEffect.where(granblue_id: entries.pluck(:status_id)).index_by(&:granblue_id)

      entries.filter_map do |entry|
        effect = catalogue[entry[:status_id]]
        unless effect
          @warnings << "Guidebook effect #{entry[:status_id]} isn't in the catalogue; skipped"
          next
        end

        guidebook_entry(effect, entry, previous[effect.id])
      end
    end

    private

    def read_entry(raw, index)
      unless raw.is_a?(Hash)
        @warnings << "Guidebook entry #{index + 1} isn't an object; skipped"
        return nil
      end

      status_id = raw['status_id']
      return skip(index, 'has no valid status_id') unless valid_status_id?(status_id)
      return skip(index, "(status #{status_id}) has no valid num") unless valid_count?(raw['num'])

      text = normalize_text(raw['name'])
      unless text && text.length <= SolomonisGuideEffect::NAME_MAX_LENGTH
        return skip(index, "(status #{status_id}) has no usable name")
      end

      { status_id: status_id, num: raw['num'].to_i, text: text, japanese: text.match?(JAPANESE_SCRIPT) }
    end

    def skip(index, reason)
      @warnings << "Guidebook entry #{index + 1} #{reason}; skipped"
      nil
    end

    def drop_repeats(entries)
      entries.group_by { |e| e[:status_id] }.map do |status_id, group|
        @warnings << "Guidebook effect #{status_id} is listed #{group.size} times; kept the first" if group.size > 1
        group.first
      end
    end

    def valid_status_id?(value)
      value.is_a?(Integer) && value.between?(1, MAX_ID)
    end

    def valid_count?(value)
      int = value.is_a?(String) && value.match?(/\A\d{1,4}\z/) ? value.to_i : value
      int.is_a?(Integer) && int.between?(1, MAX_COUNT)
    end

    def normalize_text(value)
      return nil unless value.is_a?(String)

      # @@ marks a line break in the game UI. The game keeps any word space
      # beside it ("Sephira @@coins", "First-@@position", and none in
      # Japanese), so it is removed rather than replaced with a space.
      value.gsub(LINE_BREAK, '').squish.presence
    end

    def guidebook_entry(effect, entry, previous)
      count = entry[:num]
      if count > 1 && !effect.stackable?
        @warnings << "Guidebook effect #{effect.granblue_id} can't stack but the game shows #{count}; saved as 1"
        count = 1
      end

      {
        solomonis_guide_effect: effect,
        count: count,
        display_value: display_value(effect, entry),
        acquired_order: previous&.acquired_order,
        inherited: previous&.inherited || false,
        note: previous&.note
      }
    end

    # The run-dependent text in place of the catalogue's {value}.
    def display_value(effect, entry)
      template = normalize_text(entry[:japanese] ? effect.name_jp : effect.name_en)
      return nil unless template&.include?(VALUE_PLACEHOLDER)

      pattern = template.split(VALUE_PLACEHOLDER, -1).map { |part| Regexp.escape(part) }.join('(.+?)')
      match = entry[:text].match(/\A#{pattern}\z/)
      match && match[1].strip.truncate(ExpeditionGuideEffect::DISPLAY_VALUE_MAX_LENGTH, omission: '').presence
    end
  end
end
