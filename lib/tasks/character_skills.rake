# frozen_string_literal: true

namespace :granblue do
  desc 'Build the statuses catalog from character game data.'
  task build_status_catalog: :environment do
    result = Granblue::Parsers::StatusCatalogBuilder.build_all(debug: true)
    puts "Statuses - created: #{result[:created]}, updated: #{result[:updated]}, total: #{result[:total]}"
  end

  desc "Once after the PR 7a deploy is live: copy into `sources` what the old code wrote to the characters " \
       "source columns after the copy migration ran (missing rows, and rows not rewritten since the copy whose " \
       "sha256 differs), then queues a skill build for each character it stored. Prints counts only; idempotent."
  task sync_character_sources: :environment do
    ActiveRecord::Base.logger = nil
    CharacterSkills::SourceSync.new.call
  end

  desc "Clean characters' stored game payloads down to character data (for a database where the copy " \
       "migration ran before it did that). Counts only; idempotent; queues no builds."
  task sanitize_character_sources: :environment do
    ActiveRecord::Base.logger = nil
    CharacterSkills::SourceSanitizer.new.call
  end

  desc "Build character skills from the stored sources (CharacterSkills::Build::Runner). " \
       "mode=shadow (default unless CHARACTER_SKILL_BUILD=write) builds in a rolled-back transaction and prints " \
       "the differences; mode=write keeps the result. Builds only characters whose fingerprint changed unless " \
       "all=true; ids=GRANBLUE_ID,... narrows the run (both styles); icons=false skips queueing icon downloads " \
       "(e.g. on a local copy). Exits nonzero if any character failed."
  task build_character_skills: :environment do
    ActiveRecord::Base.logger = nil
    mode = ENV['mode'].presence || (CharacterSkills.build_mode == 'write' ? 'write' : 'shadow')
    abort "mode must be shadow or write (got #{mode.inspect})" unless CharacterSkills::Build::Runner::MODES.include?(mode)

    summary = CharacterSkills::Build::Runner.new(
      mode: mode,
      ids: ENV['ids'].to_s.split(',').map(&:strip).compact_blank.presence,
      all: ENV['all'] == 'true',
      diff_limit: ENV['limit'].presence&.to_i,
      enqueue_icons: ENV['icons'] != 'false'
    ).call
    exit(1) if summary.failed.positive?
  end

  desc "Drift check: build every character in shadow mode and exit nonzero if any character's built skills " \
       'differ from the stored ones (or a build failed or came out empty). limit=N caps the printed differences.'
  task character_skill_drift: :environment do
    ActiveRecord::Base.logger = nil
    summary = CharacterSkills::Build::Runner.new(mode: 'shadow', all: true, diff_limit: (ENV['limit'] || 50).to_i).call
    exit(1) if summary.drift?
  end

  desc 'Retired: use granblue:build_character_skills (mode=write, all=true to rebuild everything).'
  task parse_character_skills: :environment do
    abort 'granblue:parse_character_skills is retired. Use: rake granblue:build_character_skills mode=write ' \
          '(builds characters without skills or with changed sources; all=true rebuilds every character).'
  end

  desc <<~DESC
    Render the parsed skill shape for the most structurally complex characters
    (or specific ids), to evaluate parser extraction by eye. No persistence.
    Usage:
      rake granblue:character_skill_shapes               # top 15 by complexity
      rake granblue:character_skill_shapes count=20
      rake granblue:character_skill_shapes ids=3040252000,3040164000
  DESC
  task character_skill_shapes: :environment do
    rows = if ENV['ids'].present?
             Granblue::Reports::CharacterSkillShape.for_ids(ENV['ids'].split(','))
           else
             Granblue::Reports::CharacterSkillShape.most_complex(limit: (ENV['count'] || 15).to_i)
           end

    output = Granblue::Reports::CharacterSkillShape.render(rows)
    report_path = Rails.root.join('tmp', 'character_skill_shapes.md')
    File.write(report_path, output)
    puts "Wrote: #{report_path}"
    puts "Selected ids: #{rows.map { |row| row[:character].granblue_id }.join(',')}"
  end

  desc 'Dry-run report on character skill parsing quality (no persistence).'
  task character_skill_report: :environment do
    chars = Character.with_source(:wiki_raw).preload(:sources)
    status_lookup = Granblue::Parsers::CharacterSkillParser.build_status_lookup
    reports = chars.find_each.map do |character|
      Granblue::Parsers::CharacterSkillParser.new(character, status_lookup: status_lookup).parse(persist: false)
    end
    report_path = Rails.root.join('tmp', 'character_skill_report.json')
    FileUtils.mkdir_p(File.dirname(report_path))
    File.write(report_path, JSON.pretty_generate(reports))
    puts "Inspected #{reports.size} characters. Details: #{report_path}"
  end
end
