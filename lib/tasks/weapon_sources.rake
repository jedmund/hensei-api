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
      bin/rails granblue:fetch_weapon_sources delay=3.0           # seconds between requests (default and minimum 2.0)
  DESC
  task fetch_weapon_sources: :environment do
    ActiveRecord::Base.logger = nil
    store = WeaponSkills::SourceStore
    ids = ENV["ids"].presence&.split(",")&.map(&:strip)
    stale_days = ENV["stale_days"].presence&.to_f
    kind = ENV["kind"].presence
    abort "unknown kind=#{kind} (#{store::KINDS.join(', ')})" if kind && !store::KINDS.include?(kind)

    cutoff = stale_days&.days&.ago
    fetcher = store::Fetcher.new(delay: Granblue::WikiThrottle.clamp(ENV["delay"].presence, warn: method(:puts)), log: ->(line) { puts line })
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

  desc <<~DESC
    Write every stored source to a gzipped JSON Lines file, to seed another database
    (granblue:import_weapon_sources) without refetching the wiki.

    Usage:
      bin/rails granblue:export_weapon_sources file=tmp/weapon_sources.jsonl.gz
  DESC
  task export_weapon_sources: :environment do
    ActiveRecord::Base.logger = nil
    path = ENV.fetch("file", "tmp/weapon_sources.jsonl.gz")
    count = WeaponSkills::SourceStore::Transfer.export(path)
    puts "Exported #{count} sources to #{path} (#{(File.size(path) / 1024.0 / 1024).round(1)} MB)"
  end

  desc <<~DESC
    Load sources exported by granblue:export_weapon_sources into this database. Dry run by
    default: prints what would change and writes nothing. Rows are matched by weapon UUID,
    kind and key; an existing row fetched later is kept. Each weapon's stored page is also
    written to weapons.wiki_raw, as a fetch would. Never talks to the wiki.

    Usage:
      bin/rails granblue:import_weapon_sources file=tmp/weapon_sources.jsonl.gz
      bin/rails granblue:import_weapon_sources file=tmp/weapon_sources.jsonl.gz write=true
  DESC
  task import_weapon_sources: :environment do
    ActiveRecord::Base.logger = nil
    transfer = WeaponSkills::SourceStore::Transfer
    header, rows = transfer.read(ENV.fetch("file", "tmp/weapon_sources.jsonl.gz"))
    plan = transfer.plan(rows)
    puts "File: #{rows.size} sources, exported #{header['exported_at']}"
    puts "Database: #{ActiveRecord::Base.connection_db_config.database} " \
         "(#{WeaponSource.count} sources, #{Weapon.count} weapons)"
    puts "Plan: #{plan.counts.sort.map { |k, v| "#{k}=#{v}" }.join(', ')}"
    puts "  #{plan.inserts.size} rows to write, #{plan.deletes.size} to remove, " \
         "#{plan.weapon_updates.size} weapons to stamp (#{plan.counts[:weapon_pages]} with a changed page)"
    plan.problems.first(20).each { |p| puts "  - #{p}" }
    puts "  … #{plan.problems.size - 20} more" if plan.problems.size > 20

    if ENV["write"] == "true"
      transfer.apply(plan)
      puts "Written. weapon_sources now: #{WeaponSource.group(:kind).count.sort.map { |k, v| "#{k}=#{v}" }.join(', ')}"
    else
      puts "Dry run; nothing written. Add write=true to apply."
    end
  end

  desc <<~DESC
    Ask gbf.wiki which stored pages were edited since they were fetched (50 titles per
    request), and optionally refetch only those weapons and pages.

    Usage:
      bin/rails granblue:check_weapon_sources                 # report only
      bin/rails granblue:check_weapon_sources refetch=true    # refetch what changed
      bin/rails granblue:check_weapon_sources delay=3.0       # seconds between requests (default and minimum 2.0)
  DESC
  task check_weapon_sources: :environment do
    ActiveRecord::Base.logger = nil
    delay = Granblue::WikiThrottle.clamp(ENV["delay"].presence, warn: method(:puts))
    fetcher = WeaponSkills::SourceStore::Fetcher.new(delay: delay, log: ->(l) { puts l })
    freshness = WeaponSkills::SourceStore::Freshness.new(fetcher: fetcher)
    result = freshness.check
    names = Weapon.where(id: result.weapon_ids).order(:granblue_id).pluck(:granblue_id, :name_en)
    puts "Checked #{result.checked} pages in #{fetcher.stats['requests']} requests."
    puts "Edited since the fetch: #{names.size} weapons, #{result.shared.size} shared pages"
    names.each { |id, name| puts "  - #{id} #{name}" }
    result.shared.each { |kind, key| puts "  - #{kind} #{key}" }
    puts "No longer on the wiki: #{result.missing.size}" if result.missing.any?
    result.missing.first(30).each { |t| puts "  - #{t}" }

    if ENV["refetch"] == "true" && result.stale?
      puts "Refetching…"
      stats = freshness.refetch(result, log: ->(l) { puts l })
      puts "Requests: #{stats['requests']}; failures: #{fetcher.failures.size}"
      fetcher.failures.each { |f| puts "  - #{f[:kind]} #{f[:key]} (weapon #{f[:weapon]}): #{f[:error]}" }
    end
  end
end
