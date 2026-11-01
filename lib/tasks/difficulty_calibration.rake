# frozen_string_literal: true

# Offline calibration for the party difficulty ruleset. Nothing here writes
# to the database: rulesets are scored in memory.
#
#   bin/rails difficulty:export_ruleset OUT=tmp/difficulty/current.json
#   bin/rails difficulty:calibrate CANDIDATE=tmp/difficulty/candidate.json OUT=tmp/difficulty/run-1
#
# calibrate compares the candidate against BASELINE (a ruleset file; defaults
# to the live ruleset). Omit CANDIDATE to report on the live ruleset alone.
namespace :difficulty do
  desc 'Write the live difficulty ruleset to a JSON file (OUT=path)'
  task export_ruleset: :environment do
    ActiveRecord::Base.logger = nil
    out = ENV.fetch('OUT', 'tmp/difficulty/current.json')
    FileUtils.mkdir_p(File.dirname(out))
    PartyDifficulty::Calibration.export(out)
    puts "Wrote #{out}"
  end

  desc 'Score parties against a candidate ruleset and write a report (CANDIDATE=, BASELINE=, OUT=)'
  task calibrate: :environment do
    ActiveRecord::Base.logger = nil
    load_ruleset = ->(path) { path ? PartyDifficulty::Calibration::Ruleset.from_file(path) : PartyDifficulty::Calibration::Ruleset.current }

    baseline_ruleset = load_ruleset.call(ENV.fetch('BASELINE', nil))
    candidate_path = ENV.fetch('CANDIDATE', nil)
    out = ENV.fetch('OUT', "tmp/difficulty/#{Time.current.strftime('%Y%m%d-%H%M%S')}")

    puts 'Scoring the baseline…'
    baseline = PartyDifficulty::Calibration.new(baseline_ruleset).score_all

    if candidate_path
      candidate_ruleset = load_ruleset.call(candidate_path)
      puts 'Scoring the candidate…'
      results = PartyDifficulty::Calibration.new(candidate_ruleset).score_all
      report = PartyDifficulty::Calibration::Report.new(
        ruleset: candidate_ruleset, results: results, baseline: baseline, label: File.basename(candidate_path, '.json')
      )
    else
      report = PartyDifficulty::Calibration::Report.new(ruleset: baseline_ruleset, results: baseline, label: 'live ruleset')
    end

    report.write(out)
    puts "Wrote #{out}/report.md and #{out}/parties.csv"
  end
end
