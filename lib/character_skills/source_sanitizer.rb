# frozen_string_literal: true

module CharacterSkills
  # Re-stores characters' game payload sources through Granblue::GamePayload.sanitize, for a
  # database where the copy migration ran before it sanitized (local dev copies). Batched,
  # idempotent (a clean row is left alone), keeps fetch times, queues no builds (sanitizing
  # doesn't change what the build reads). → { kind => [checked, cleaned] }
  class SourceSanitizer
    KINDS = %w[game_raw_en game_raw_jp].freeze

    def initialize(io: $stdout)
      @io = io
    end

    def call
      results = Character.without_skill_build { KINDS.to_h { |kind| [kind, sanitize(kind)] } }
      results.each { |kind, (checked, cleaned)| @io.puts "#{kind}: #{checked} checked, #{cleaned} cleaned" }
      results
    end

    private

    def sanitize(kind)
      checked = 0
      cleaned = 0
      Source.where(owner_type: Character.polymorphic_name, kind: kind).find_each(batch_size: 100) do |source|
        checked += 1
        body = Source.serialize(kind, Granblue::GamePayload.sanitize(source.value))
        next if body == source.body

        source.skip_owner_hook = true
        source.update!(body: body, sha256: Source.digest(body))
        cleaned += 1
      end
      [checked, cleaned]
    end
  end
end
