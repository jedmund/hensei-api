# frozen_string_literal: true

module Granblue
  module Parsers
    # Which status a wiki status name means. gbf.wiki's Module:StatusList (D33, StatusList)
    # answers first: "DEF Down 4" is DEF Lowered (Local), variant 4, game id 1020_14. For names it
    # lacks, a trailing number is the icon variant (D31: turns, level or uses) and the rest is the
    # status. The number and the exact display id belong to the effect (skill_effects.status_variant,
    # game_status_id). Bases in data/statuses/numbered_exceptions.json keep their number.
    module StatusName
      EXCEPTIONS_PATH = Rails.root.join('data/statuses/numbered_exceptions.json')
      NUMBERED = /\A(.*\S)\s+(\d+)\z/

      module_function

      # How a wiki status name resolves: the status it names (name, after the approved display
      # aliases), the variant number, and what gbf.wiki's Module:StatusList knows about it
      # (resolution: StatusList::Resolution, nil for names the list lacks).
      Resolved = Struct.new(:name, :variant, :resolution, keyword_init: true) do
        def game_status_id = resolution&.status_id
        def from_status_list? = !resolution.nil?
      end

      # StatusList first ("DEF Down 4" → DEF Lowered (Local), variant 4; "Charm" → Charmed); for a
      # name it lacks, the trailing number is stripped and the rest looked up again ("Hellfire Crest
      # 9"), else the stripped name is the status. Bases in numbered_exceptions.json keep their number.
      def resolve(name)
        name = name.to_s.squish
        listed = StatusList.resolve(name)
        return Resolved.new(name: StatusAliases.canonical(listed.base), variant: listed.variant, resolution: listed) if listed

        match = NUMBERED.match(name)
        if match.nil? || exceptions.include?(Status.normalize_name(match[1]))
          return Resolved.new(name: StatusAliases.canonical(name), variant: nil, resolution: nil)
        end

        listed = StatusList.resolve(match[1])
        Resolved.new(name: StatusAliases.canonical(listed ? listed.base : match[1]), variant: match[2].to_i, resolution: listed)
      end

      # → [status name, variant number or nil]
      def split(name)
        resolved = resolve(name)
        [resolved.name, resolved.variant]
      end

      def base(name)
        split(name).first
      end

      def exceptions
        @exceptions ||= load_exceptions
      end

      def reset!
        @exceptions = nil
      end

      def exceptions_sha256(path = EXCEPTIONS_PATH)
        File.file?(path) ? Digest::SHA256.file(path).hexdigest : '-'
      end

      def load_exceptions(path = EXCEPTIONS_PATH)
        return Set.new unless File.file?(path) && File.size(path).positive?

        JSON.parse(File.read(path)).to_set { |entry| Status.normalize_name(entry.fetch('name_en')) }
      end

      # What one numbered mention says its number is: "uses" when its n= is the number (Other
      # Self 1 … n=1), "turns" when its t= is (DEF Down 4 … t=4T; 2.5T counts as 2), else
      # "uses" when it carries n= at all; nil when nothing says. (DMG Taken Amplified 1 … t=1T
      # n=6 is 1 turn: the number follows t=, not n=.)
      def mention_kind(number, params)
        return if number.nil?

        params = params.to_h
        return 'uses' if params['n'].to_s.strip == number.to_s

        turns = params['t'].to_s[/\A(\d+(?:\.\d+)?)\s*t/i, 1]
        return 'turns' if turns && (turns.to_f - number).abs < 0.6

        'uses' if params['n'].present?
      end

      # The family's kind from its numbered mentions (D31a): uses when they carry n=; turns
      # when the mentions with a duration in turns match their number (80%); level when none
      # do (counters: Crests, Tuning, Hype…); nil when the vote is split.
      # evidence: { uses:, turns:, other_turns:, plain: } counts.
      def family_kind(evidence)
        uses, turns, other = evidence.values_at(:uses, :turns, :other_turns).map(&:to_i)
        return 'uses' if uses.positive? && turns.zero? && other.zero?
        return 'level' if turns.zero? && uses.zero?
        return 'turns' if uses.zero? && turns >= 0.8 * (turns + other)

        nil
      end

      # The game's display ids are a 4-digit base plus an optional variant: "1020_14",
      # "1019_0_40", or digits appended ("61433" = 6143, level 3).
      def base_game_id(id)
        id.to_s[/\A\d{4}/] || id.to_s.split('_').first
      end
    end
  end
end
