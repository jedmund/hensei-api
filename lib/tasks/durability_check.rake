# frozen_string_literal: true

namespace :granblue do
  desc "Panel-line drift check: panel_lines must match GridDamage::PanelPresenter::LINES. Reparse " \
       "durability (curation surviving a rebuild) is checked by granblue:build_weapon_skills mode=shadow, " \
       "granblue:skill_parity and the golden specs (spec/requests/goldens_spec.rb)."
  task durability_check: :environment do
    puts "Reparse durability: run bin/rails granblue:build_weapon_skills all=true mode=shadow, " \
         "bin/rails granblue:skill_parity and bundle exec rspec spec/requests/goldens_spec.rb."

    # panel_lines is the authoritative panel; LINES is its bare-DB fallback snapshot.
    # They must stay in lockstep until LINES is retired — a new line added to only one
    # of them renders differently in tests/fresh environments than in dev/prod.
    db_lines = PanelLine.order(:position).pluck(:boost_type, :series, :label_en, :slug, :group_name)
    if db_lines.present? && db_lines != GridDamage::PanelPresenter::LINES
      code = GridDamage::PanelPresenter::LINES
      (code - db_lines).each { |r| puts "  LINES drift (code-only): #{r.inspect}" }
      (db_lines - code).each { |r| puts "  LINES drift (db-only):   #{r.inspect}" }
      puts "DURABILITY: RED — panel_lines and PanelPresenter::LINES have drifted"
      exit(1)
    end
    puts "panel_lines and PanelPresenter::LINES match"
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
      "series_non_summon_boosted" => WeaponSeries.where(summon_boosted: false).order(:slug).pluck(:slug)
    }
    path = Rails.root.join("data/boost_registry.json")
    File.write(path, "#{JSON.pretty_generate(payload)}\n")
    puts "Exported boost registry: #{payload['panel_lines'].size} lines, " \
         "#{payload['boost_types'].size} boost-type rows"
  end
end

namespace :granblue do
  desc "Export the weapon-skill family registry to data/weapon_skill_families.json"
  task export_weapon_skill_families: :environment do
    rows = WeaponSkillFamily.order(:name).map do |f|
      f.attributes.slice("name", "aura_boostable", "boosts", "icon_stems", "color").compact
    end
    File.write(Rails.root.join("data/weapon_skill_families.json"), "#{JSON.pretty_generate(rows)}\n")
    puts "Exported #{rows.size} weapon skill families"
  end
end

namespace :granblue do
  desc "Import {{Weapon Skills/*}} family templates: registry header always upserts; " \
       "curves fill gaps only with apply=true. Mismatches are reported, never applied."
  task import_family_templates: :environment do
    apply = ENV["apply"] == "true"
    names = ENV["only"].presence&.split(",") || Granblue::Extractors::FamilyTemplateImporter::NAV_FAMILIES
    results = Granblue::Extractors::FamilyTemplateImporter.import(names, apply: apply)
    results.each do |r|
      flags = []
      flags << "missing=#{r.missing.size}" if r.missing.any?
      flags << "MISMATCH=#{r.mismatches.size}" if r.mismatches.any?
      flags << "skipped=#{r.skipped.size}" if r.skipped.any?
      puts format("%<f>-28s %<s>-12s %<x>s", f: r.family, s: r.status, x: flags.join(" "))
      r.mismatches.each { |m| puts "    #{m[:series]}/#{m[:size]}/#{m[:boost_type]}: #{m[:diffs].join('; ')}" }
    end
    puts "TOTAL: #{results.count { |r| r.status == 'ok' }}/#{results.size} ok, " \
         "#{results.sum { |r| r.missing.size }} missing rows, " \
         "#{results.sum { |r| r.mismatches.size }} mismatches"
  end
end
