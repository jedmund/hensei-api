# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Fetch every gbf.wiki input the weapon-skill parse reads into weapon_sources. This is
    the only step that talks to the wiki; parsing and building read the stored sources.

    Stores each weapon's page (wiki_raw, also written to weapons.wiki_raw), the
    expandtemplates output for series-template pages (expanded), the pages its structural
    parse follows (transclusion), the Template:Weapon Skills/* family pages
    (family_template) and the key series pages KeySkillExtractor reads (wiki_raw, no weapon).

    Resumable: weapons and shared pages already stored are skipped, so an interrupted run
    picks up where it stopped. Throttled, with retries and backoff.

    Usage:
      bin/rails granblue:fetch_weapon_sources                     # everything not yet stored
      bin/rails granblue:fetch_weapon_sources stale_days=30       # also refetch sources older than 30 days
      bin/rails granblue:fetch_weapon_sources stale_days=0        # refetch everything
      bin/rails granblue:fetch_weapon_sources ids=1040415000,...  # these weapons (always refetched)
      bin/rails granblue:fetch_weapon_sources kind=family_template
      bin/rails granblue:fetch_weapon_sources delay=3.0           # seconds between requests (default 2.0)
  DESC
  task fetch_weapon_sources: :environment do
    ActiveRecord::Base.logger = nil
    store = WeaponSkills::SourceStore
    ids = ENV["ids"].presence&.split(",")&.map(&:strip)
    stale_days = ENV["stale_days"].presence&.to_f
    kind = ENV["kind"].presence
    abort "unknown kind=#{kind} (#{store::KINDS.join(', ')})" if kind && !store::KINDS.include?(kind)

    cutoff = stale_days&.days&.ago
    fetcher = store::Fetcher.new(delay: ENV.fetch("delay", "2.0").to_f, log: ->(line) { puts line })
    fresh = lambda do |scope|
      scope = scope.where(fetched_at: cutoff..) if cutoff
      scope
    end
    errors = []

    weapon_kinds = kind ? [kind] & store::Fetcher::WEAPON_KINDS : store::Fetcher::WEAPON_KINDS
    if weapon_kinds.any?
      weapons = Weapon.where.not(wiki_en: [nil, ""]).order(:granblue_id)
      if ids
        weapons = weapons.where(granblue_id: ids)
      else
        marker = weapon_kinds.include?("wiki_raw") ? "wiki_raw" : weapon_kinds.first
        done = fresh.call(WeaponSource.where(kind: marker).where.not(weapon_id: nil))
        weapons = weapons.where.not(id: done.select(:weapon_id))
      end
      total = weapons.count
      puts "Fetching #{weapon_kinds.join(', ')} for #{total} weapons…"
      weapons.each_with_index do |weapon, i|
        fetcher.fetch_weapon(weapon, kinds: weapon_kinds)
        puts "  (#{i + 1}/#{total}) #{weapon.granblue_id} #{weapon.name_en}"
      rescue StandardError => e
        errors << "#{weapon.granblue_id} (#{weapon.name_en}): #{e.class}: #{e.message}"
        puts "  (#{i + 1}/#{total}) ERROR #{weapon.granblue_id} #{weapon.name_en}: #{e.message}"
      end
    end

    if ids.nil? && (kind.nil? || kind == "family_template")
      names = Granblue::Extractors::FamilyTemplateImporter::NAV_FAMILIES
      have = fresh.call(WeaponSource.where(kind: "family_template", weapon_id: nil)).pluck(:key).to_set
      todo = names.reject { |n| have.include?(Granblue::Extractors::FamilyTemplateImporter.template_title(n)) }
      puts "Fetching #{todo.size} family templates…"
      todo.each { |name| fetcher.fetch_family_template(name) }
    end

    if ids.nil? && (kind.nil? || kind == "wiki_raw")
      pages = Granblue::Extractors::KeySkillExtractor::SERIES_PAGES
      have = fresh.call(WeaponSource.where(kind: "wiki_raw", weapon_id: nil)).pluck(:key).to_set
      todo = pages.reject { |p| have.include?(p) }
      puts "Fetching #{todo.size} key series pages…"
      todo.each { |page| fetcher.fetch_series_page(page) }
    end

    puts
    puts "Requests: #{fetcher.stats['requests']}; stored this run: " \
         "#{fetcher.stats.except('requests').sort.map { |k, v| "#{k}=#{v}" }.join(', ')}"
    puts "weapon_sources now: #{WeaponSource.group(:kind).count.sort.map { |k, v| "#{k}=#{v}" }.join(', ')}; " \
         "page kinds: #{WeaponSource.where(kind: 'wiki_raw').where.not(weapon_id: nil).group(:page_kind).count}"
    failures = errors + fetcher.failures.map { |f| "#{f[:kind]} #{f[:key]} (weapon #{f[:weapon]}): #{f[:error]}" }
    puts "Failures: #{failures.size}"
    failures.each { |f| puts "  - #{f}" }
  end
end
