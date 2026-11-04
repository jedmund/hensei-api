# frozen_string_literal: true

module WikiImport
  ##
  # Reads a wiki item's uncap: "0"-"5" stars, "t1"-"t5" (uncap 6 at that
  # transcendence step; "6" is t5), or nil for what the wiki shows without one
  # (#default_uncap). Values past the item's max are lowered to it, with a
  # warning; an unreadable value falls back to the default.
  class UncapResolver
    # @param report [WikiImport::Report]
    def initialize(report)
      @report = report
    end

    # @param kind [Symbol] :character, :weapon or :summon
    # @param entry [WikiImport::Payload::Item]
    # @param record [Character, Weapon, Summon]
    # @return [Array(Integer, Integer)] uncap_level and transcendence_step
    def resolve(kind, entry, record)
      return default_uncap(kind, record) if entry.uncap.nil?

      uncap, step = parse_uncap(entry.uncap)
      if uncap.nil?
        @report.warn('invalid_uncap', "#{kind} #{entry.position}", **Report.at(kind, entry))
        return default_uncap(kind, record)
      end

      max_uncap, max_step = max_uncap(kind, record)
      if uncap > max_uncap || step > max_step
        @report.warn('uncap_clamped', "#{kind} #{entry.position}", **Report.at(kind, entry))
        uncap = [uncap, max_uncap].min
        step = uncap == 6 ? [step, max_step].min : 0
      end
      [uncap, step]
    end

    private

    def parse_uncap(value)
      case value
      when /\A[0-5]\z/ then [value.to_i, 0]
      when '6' then [6, 5]
      when /\At([1-5])\z/ then [6, Regexp.last_match(1).to_i]
      end
    end

    # [uncap_level, transcendence_step] for an item the template gives no
    # uncap, matching what the wiki renders and when our exporter omits it:
    # - characters: base art (the exporter omits uchar below 5★), so at most 4★;
    # - weapons: level 200, the max without transcendence (the exporter always
    #   writes u for transcendable weapons; Dark Opus at 5★ is the exception);
    # - summons: the full max, transcendence included (omitted at t5).
    def default_uncap(kind, record)
      case kind
      when :character then [[4, record.max_uncap_level].min, 0]
      when :weapon then [[record.max_uncap_level, 5].min, 0]
      else max_uncap(kind, record)
      end
    end

    # [uncap_level, transcendence_step] at the item's max.
    def max_uncap(kind, record)
      uncap = record.max_uncap_level
      return [uncap, uncap == 6 ? record.max_transcendence_stage : 0] if kind == :character

      [uncap, record.max_transcendence_step]
    end
  end
end
