# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Download weapon skill icons (EN + JA) from the game CDN to S3/local, keyed by
    the distinct normalized stems on weapon skill versions. Files are stored under
    weapon-skill-icons/{en,ja}/ using our INTERNAL element numbering; the CDN is
    fetched using Granblue element numbering.
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

    # target stem (internal numbering, stored name) => source stem (Granblue
    # numbering, CDN name). Deduped across all versions.
    pairs = {}
    WeaponSkillVersion.includes(weapon_skill: :weapon)
                      .where.not(icon: [nil, ''])
                      .find_each do |version|
      target = version.icon_stem
      source = version.icon_source_stem
      next if target.blank? || source.blank?

      pairs[target] ||= source
    end

    puts "Distinct weapon skill icons: #{pairs.size} (storage=#{storage}, force=#{force}, throttle=#{throttle})"

    downloaded = Hash.new(0)
    skipped = Hash.new(0)
    failed = Hash.new(0)
    failures = []

    pairs.each_with_index do |(target, source), index|
      results = Granblue::Downloaders::WeaponSkillIconDownloader.new(
        target, source_stem: source, storage: storage, force: force
      ).download

      results.each do |lang, result|
        if result[:skipped]
          skipped[lang] += 1
        elsif result[:success]
          downloaded[lang] += 1
        else
          failed[lang] += 1
          failures << "#{lang}: #{source} -> #{target}"
        end
      end

      sleep(throttle) if throttle.positive?
      puts "  [#{index + 1}/#{pairs.size}] processed" if ((index + 1) % 100).zero?
    end

    puts "Done."
    puts "  EN: downloaded=#{downloaded['en']} skipped=#{skipped['en']} failed=#{failed['en']}"
    puts "  JA: downloaded=#{downloaded['ja']} skipped=#{skipped['ja']} failed=#{failed['ja']}"
    puts "Failures (#{failures.size}): #{failures.first(40).join(', ')}#{'…' if failures.size > 40}" if failures.any?
  end
end
