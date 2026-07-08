# frozen_string_literal: true

namespace :granblue do
  desc "Durability check: bulk-reparse every golden-involved weapon, then validate " \
       "all panel references — inside a rolled-back transaction. Green means every " \
       "curation survives reparse (#62's acceptance test). Add refetch=true to also " \
       "re-fetch wikitext (slow, hits the wiki)."
  task durability_check: :environment do
    refetch = ENV["refetch"] == "true"
    references = Rails.root.glob("data/panel_references/*.json")
                     .map { |f| JSON.parse(File.read(f)) }
    parties = references.filter_map { |r| Party.find_by(shortcode: r["party"]) }
    abort "no golden parties found" if parties.empty?

    weapons = parties.flat_map { |p| p.weapons.map(&:weapon) }.uniq
                     .select { |w| w.wiki_raw.present? }
    puts "Reparsing #{weapons.size} golden-involved weapons (#{parties.size} parties)…"

    failed = true
    ActiveRecord::Base.transaction do
      weapons.each do |w|
        Granblue::EntityReparser.new(w, refetch: refetch).reparse
      rescue StandardError => e
        puts "  REPARSE ERROR #{w.name_en}: #{e.class}: #{e.message[0..120]}"
      end

      results = Granblue::PanelValidator.run
      failed = results.any? { |r| !r.ok }
      results.each do |r|
        puts format("  %-8s %s", r.party, r.ok ? "ok" : "FAIL")
        next if r.ok

        r.mismatches.first(8).each do |m|
          puts "           #{m[:label]}: ours=#{m[:ours].inspect} expected=#{m[:expected].inspect}"
        end
      end

      puts failed ? "\nDURABILITY: RED — reparse destroys curations" : "\nDURABILITY: GREEN"
      raise ActiveRecord::Rollback # never persist the experiment
    end
    exit(1) if failed
  end
end
