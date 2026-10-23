# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Character skill coverage: what the stored sources and built skills still lack
    (CharacterSkills::Coverage). Read-only; run it before and after each backfill run.

    Usage:
      rake granblue:character_skill_coverage
      rake granblue:character_skill_coverage ids=3040252000,3040164000      # these granblue_ids (both style rows)
      rake granblue:character_skill_coverage format=csv                     # also list every gap to tmp/character_skill_coverage.csv
      rake granblue:character_skill_coverage format=csv out=tmp/before.csv
      rake granblue:character_skill_coverage s3=true                        # HEAD-check every stored stem in icons/abilities/
      rake granblue:character_skill_coverage s3=true s3_delay=0.1           # seconds between HEAD requests (default 0.05)

    Read-only against any database:
      PGOPTIONS='-c default_transaction_read_only=on' bin/rails granblue:character_skill_coverage
  DESC
  task character_skill_coverage: :environment do
    ActiveRecord::Base.logger = nil
    format = ENV['format'].presence || 'text'
    abort "Error: format must be text or csv (got #{format.inspect})" unless %w[text csv].include?(format)

    coverage = CharacterSkills::Coverage.new(
      ids: CharacterSkills::SourceFetch.ids(ENV.fetch('ids', nil)),
      check_bucket: ENV['s3'] == 'true',
      s3_delay: (ENV['s3_delay'].presence || 0.05).to_f
    )
    coverage.print($stdout)

    if format == 'csv'
      path = ENV['out'].presence || Rails.root.join('tmp/character_skill_coverage.csv').to_s
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, coverage.to_csv)
      puts
      puts "Wrote #{coverage.gaps.sum(&:count)} gap rows to #{path}"
    end
  end
end
