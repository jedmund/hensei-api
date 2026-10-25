# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Download weapon skill icons (EN + JA) from the game CDN to S3/local, keyed by
    the distinct normalized stems on weapon skill versions. Files are stored under
    icons/weapon-skills/{en,ja}/ with the CDN's own file names.
    Usage:
      rake granblue:download_weapon_skill_icons                 # storage=both
      rake granblue:download_weapon_skill_icons storage=s3
      rake granblue:download_weapon_skill_icons force=true throttle=0.1
  DESC
  task download_weapon_skill_icons: :environment do
    require_relative '../granblue/downloaders/base_downloader'
    require_relative '../granblue/downloaders/weapon_skill_icon_downloader'

    storage = (ENV['storage'] || 'both').to_sym
    force = ENV['force'] == 'true'
    throttle = (ENV['throttle'] || '0.2').to_f

    stems = WeaponSkillVersion.includes(weapon_skill: :weapon)
                              .where.not(icon: [nil, ''])
                              .find_each.filter_map(&:icon_stem)
                              .uniq

    puts "Distinct weapon skill icons: #{stems.size} (storage=#{storage}, force=#{force}, throttle=#{throttle})"

    downloaded = Hash.new(0)
    skipped = Hash.new(0)
    failed = Hash.new(0)
    failures = []

    stems.each_with_index do |stem, index|
      results = Granblue::Downloaders::WeaponSkillIconDownloader.new(stem, storage: storage, force: force).download

      results.each do |lang, result|
        if result[:skipped]
          skipped[lang] += 1
        elsif result[:success]
          downloaded[lang] += 1
        else
          failed[lang] += 1
          failures << "#{lang}: #{stem}"
        end
      end

      sleep(throttle) if throttle.positive?
      puts "  [#{index + 1}/#{stems.size}] processed" if ((index + 1) % 100).zero?
    end

    puts "Done."
    puts "  EN: downloaded=#{downloaded['en']} skipped=#{skipped['en']} failed=#{failed['en']}"
    puts "  JA: downloaded=#{downloaded['ja']} skipped=#{skipped['ja']} failed=#{failed['ja']}"
    puts "Failures (#{failures.size}): #{failures.first(40).join(', ')}#{'…' if failures.size > 40}" if failures.any?
  end
end
