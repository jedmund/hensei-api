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
