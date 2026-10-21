# frozen_string_literal: true

module CharacterSkills
  # What the character source fetch tasks (fetch_wiki_data, download_jp_wiki,
  # fetch_game_data) share: option parsing, and the step after the fetch. The fetches
  # run inside Character.without_skill_build, so nothing is built per row; afterwards
  # this prints the build command to run next, or runs it when build=shadow|write
  # was passed, over the characters whose sources changed.
  module SourceFetch
    BUILD_MODES = Build::Runner::MODES
    # Longer lists go through changed_out= instead of the command line.
    INLINE_IDS = 30

    class OptionError < StandardError; end

    module_function

    # "a, b,,c" → ["a", "b", "c"]; nil when blank.
    def ids(value)
      value.to_s.split(',').map(&:strip).compact_blank.presence
    end

    # "3" or "1,2" → [3] / [1, 2]; nil when blank.
    def rarities(value)
      list = ids(value)
      return unless list

      list.map do |entry|
        raise OptionError, "rarity must be 1, 2 or 3 (got #{entry.inspect})" unless %w[1 2 3].include?(entry)

        entry.to_i
      end.uniq
    end

    def build_mode(value)
      return if value.blank?
      raise OptionError, "build must be shadow or write (got #{value.inspect})" unless BUILD_MODES.include?(value)

      value
    end

    # Writes the changed list, then either runs the build (build: shadow|write) or
    # prints the command for it. Returns the build's Summary, or nil.
    def finish(summary, build: nil, changed_out: nil, io: $stdout)
      if changed_out.present?
        summary.write_changed(changed_out)
        io.puts "Wrote #{summary.changed_ids.size} changed granblue_ids to #{changed_out}"
      end

      if summary.changed_ids.empty?
        io.puts 'No character source changed; nothing to build.'
        return
      end

      return Build::Runner.new(mode: build, ids: summary.changed_ids).call if build

      print_next_step(summary, changed_out, io)
      nil
    end

    def print_next_step(summary, changed_out, io)
      ids = summary.changed_ids
      io.puts
      io.puts "Next: build the #{ids.size} characters whose sources changed. Shadow first, review, then write:"
      io.puts '  bin/rails granblue:build_character_skills mode=shadow   # every character with a stale fingerprint'
      if ids.size <= INLINE_IDS
        io.puts "  bin/rails granblue:build_character_skills mode=shadow ids=#{ids.join(',')}"
      elsif changed_out.present?
        io.puts "  bin/rails granblue:build_character_skills mode=shadow ids=$(paste -sd, #{changed_out})"
      end
      io.puts '  bin/rails granblue:build_character_skills mode=write    # after the review'
    end
  end
end
