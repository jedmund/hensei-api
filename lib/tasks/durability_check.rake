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
        puts format("  %<party>-8s %<status>s", party: r.party, status: r.ok ? "ok" : "FAIL")
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

namespace :granblue do
  desc "Export the boost-type registry (panel lines, caps, flags) to data/boost_registry.json"
  task export_boost_registry: :environment do
    payload = {
      "panel_lines" => PanelLine.order(:position).map do |l|
        { "boost_type" => l.boost_type, "series" => l.series, "label_en" => l.label_en,
          "slug" => l.slug, "group" => l.group_name, "position" => l.position }.compact
      end,
      "boost_types" => WeaponSkillBoostType.order(:key).filter_map do |b|
        row = { "key" => b.key }
        row["display_cap"] = b.display_cap.to_f if b.display_cap
        row["amplifiable"] = b.amplifiable unless b.amplifiable.nil?
        row["hidden"] = true if b.hidden
        row.size > 1 ? row : nil
      end,
      "series_summon_boosted" => WeaponSeries.where(summon_boosted: false).order(:slug).pluck(:slug)
    }
    path = Rails.root.join("data/boost_registry.json")
    File.write(path, "#{JSON.pretty_generate(payload)}\n")
    puts "Exported boost registry: #{payload['panel_lines'].size} lines, " \
         "#{payload['boost_types'].size} boost-type rows"
  end
end
