# frozen_string_literal: true

namespace :granblue do
  desc 'Build the statuses catalog from character game data.'
  task build_status_catalog: :environment do
    result = Granblue::Parsers::StatusCatalogBuilder.build_all(debug: true)
    puts "Statuses - created: #{result[:created]}, updated: #{result[:updated]}, failed: #{result[:failed]}, " \
         "total: #{result[:total]}"
  end

  desc 'Merge statuses that share a name, recompute family/level and fill name_key ' \
       '(CharacterSkills::StatusCatalogueRepair; bin/setup-pipeline-db runs it on older catalogue dumps).'
  task repair_status_catalogue: :environment do
    puts "Statuses repaired: #{CharacterSkills::StatusCatalogueRepair.call}"
  end

  desc "Fetch gbf.wiki's Module:StatusList into the wiki_status_list source row (one request, after the wiki delay; " \
       'writes only when it changed). The build reads the row, never the wiki.'
  task fetch_wiki_status_list: :environment do
    result = Sources::WikiStatusList.fetch!
    puts "Module:StatusList #{result.changed ? 'updated' : 'unchanged'} (#{result.source.body.bytesize} bytes, " \
         "sha256 #{result.source.sha256[0, 12]})"
  end

  desc 'Write the status rename/merge list the naming rule implies (D32) for review: out=DIR (default tmp/status_renames), ' \
       'groups=FILE (JSON [[name, …], …] of extra aliases to merge). Changes nothing in the database.'
  task status_rename_list: :environment do
    out = Pathname(ENV.fetch('out', Rails.root.join('tmp/status_renames').to_s))
    groups = ENV['groups'].present? ? JSON.parse(File.read(ENV['groups'])) : []
    mentions = Hash.new(0)
    raw_names = Set.new
    Character.with_source(:wiki_raw).select(:id).find_in_batches(batch_size: 200) do |batch|
      Character.preload_sources(batch, kinds: %w[wiki_raw]).each do |character|
        Granblue::Parsers::StatusMentions.in(character.wiki_raw).each do |mention|
          mentions[Status.normalize_name(Granblue::Parsers::StatusName.base(mention.name))] += 1
          raw_names << Status.normalize_name(mention.name.sub(/\s+\d+\z/, ''))
        end
      end
    end
    counts = SkillEffect.group(:status_id).count
    Granblue::Parsers::StatusList.refresh!
    statuses = Status.order(:name_en).map do |s|
      { name: s.name_en, category: s.category, effects: counts[s.id].to_i,
        wiki_label: Granblue::Parsers::StatusList.resolve(s.name_en)&.label }
    end
    vocabulary = raw_names | Granblue::Parsers::StatusList.current.vocabulary
    list = CharacterSkills::StatusRenameList.new(statuses: statuses, mentions: mentions, groups: groups, vocabulary: vocabulary)
    out.mkpath
    out.join('aliases.json').write("#{JSON.pretty_generate(list.aliases)}\n")
    out.join('groups.json').write(JSON.pretty_generate(list.groups.map(&:to_h)))
    puts "#{list.groups.size} statuses renamed or merged, #{list.aliases.size} aliases → #{out}"
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
