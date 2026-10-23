# frozen_string_literal: true

namespace :granblue do
  desc "Compare the structure compiler (stored sources) with this database's weapon-skill slots and versions. " \
       "ids=ID,ID limits the weapons, series=slug,slug the series. Writes " \
       "data/weapon_skill_parity/compare_structure_last.json; fails on unclassified differences."
  task compare_structure: :environment do
    ActiveRecord::Base.logger = nil
    comparison = WeaponSkills::Build::Structure::Comparison.new(
      weapon_ids: ENV["ids"].to_s.split(",").map(&:strip).presence,
      series: ENV["series"].to_s.split(",").map(&:strip).presence
    ).run
    comparison.write

    report = comparison.report
    puts report["counts"].map { |k, v| "#{k}: #{v}" }.join("\n")
    puts "redundant ops: #{report['redundant_ops'].size}"
    puts "warnings: #{report['warnings'].size}"
    comparison.differences.group_by { |d| d["key"].split("|").first }.each do |gid, diffs|
      unknown = diffs.select { |d| d["class"] == "unknown" }
      next if unknown.empty?

      puts "#{gid} #{unknown.first['weapon']}"
      unknown.each { |d| puts "  #{d['key'].split('|')[1..].join('|')}: #{d['today'].inspect} → #{d['ours'].inspect}" }
    end
    exit(1) if comparison.unknown.any?
  end
end
