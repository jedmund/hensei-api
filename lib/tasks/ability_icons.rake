# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Download character ability icons from the game CDN to S3/local, keyed by the
    distinct game_icon stems persisted on character skill versions.
    Usage:
      rake granblue:download_ability_icons                 # storage=both
      rake granblue:download_ability_icons storage=s3
      rake granblue:download_ability_icons force=true throttle=0.1
  DESC
  task download_ability_icons: :environment do
    storage = (ENV['storage'] || 'both').to_sym
    force = ENV['force'] == 'true'
    throttle = (ENV['throttle'] || '0.2').to_f

    stems = CharacterSkillVersion.where.not(game_icon: nil).distinct.pluck(:game_icon).sort
    puts "Distinct ability icon stems: #{stems.size} (storage=#{storage}, force=#{force}, throttle=#{throttle})"

    downloaded = skipped = failed = 0
    failures = []

    stems.each_with_index do |stem, index|
      result = Granblue::Downloaders::AbilityIconDownloader.new(stem, storage: storage, force: force).download
      if result[:skipped]
        skipped += 1
      elsif result[:success]
        downloaded += 1
        sleep(throttle) if throttle.positive?
      else
        failed += 1
        failures << stem
      end

      puts "  [#{index + 1}/#{stems.size}] processed (#{downloaded} dl, #{skipped} skip, #{failed} fail)" if ((index + 1) % 100).zero?
    end

    puts "Done. downloaded=#{downloaded} skipped=#{skipped} failed=#{failed}"
    puts "Failed stems (likely no asset at ability/m): #{failures.first(40).join(', ')}#{'…' if failures.size > 40}" if failures.any?
  end
end
