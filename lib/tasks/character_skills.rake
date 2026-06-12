# frozen_string_literal: true

namespace :granblue do
  desc 'Build the statuses catalog from character game data.'
  task build_status_catalog: :environment do
    result = Granblue::Parsers::StatusCatalogBuilder.build_all(debug: true)
    puts "Statuses - created: #{result[:created]}, updated: #{result[:updated]}, total: #{result[:total]}"
  end

  desc <<~DESC
    Parse character skills from wiki_raw + game data into character_skills graph.
    Usage:
      rake granblue:parse_character_skills            # missing only
      rake granblue:parse_character_skills force=true # re-parse all
  DESC
  task parse_character_skills: :environment do
    overwrite = ENV['force'] == 'true'
    result = Granblue::Parsers::CharacterSkillParser.persist_all(debug: true, overwrite: overwrite)
    report_path = Rails.root.join('tmp', 'character_skill_parse_report.json')
    FileUtils.mkdir_p(File.dirname(report_path))
    File.write(report_path, JSON.pretty_generate(result))
    puts "Processed: #{result[:processed]}  Skipped: #{result[:skipped]}  Errors: #{result[:errors].size}"
    puts "Report: #{report_path}"
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
    chars = Character.where.not(wiki_raw: [nil, ''])
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
