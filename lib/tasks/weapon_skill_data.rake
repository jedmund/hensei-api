# frozen_string_literal: true

require "set"

namespace :granblue do
  # Source of truth: the checked-in wiki templates. Override with dir=<path>.
  def wiki_source_dir
    ENV["dir"] ? Pathname.new(ENV["dir"]) : Rails.root.join("..", "docs", "damage", "wiki-source")
  end

  desc "Extract weapon_skill_data from wiki-source templates -> data/weapon_skill_data.json"
  task extract_weapon_skill_data: :environment do
    require Rails.root.join("lib/granblue/extractors/weapon_skill_data_extractor")
    skill_dir = wiki_source_dir.join("weapon-skill-types")
    wpn_dir   = wiki_source_dir.join("wpnskill-templates")
    ex = Granblue::Extractors::WeaponSkillDataExtractor.new

    gen = []
    Dir[skill_dir.join("*.wikitext")].sort.each do |f|
      name = File.basename(f, ".wikitext").tr("_", " ")
      text = File.read(f)
      # follow a {{WpnSkill<Name>}} delegation: append the sub-template so its
      # table is parsed under this subpage's WsBox (name + boosts).
      if (m = text.match(/\{\{(WpnSkill[A-Za-z0-9]+)/))
        sub = wpn_dir.join("#{m[1]}.wikitext")
        text += "\n" + File.read(sub) if File.exist?(sub)
      end
      gen.concat(ex.extract(text, name: name))
    end
    gen_modifiers = gen.map { |r| r[:modifier] }.uniq

    file = Rails.root.join("data", "weapon_skill_data.json")
    existing = JSON.parse(File.read(file))
    # per-modifier authority: gen replaces all rows for the modifiers it covers;
    # rows for not-yet-covered modifiers are kept as-is.
    kept = existing.reject { |r| gen_modifiers.include?(r["modifier"]) }
    merged = (kept + gen.map { |r| r.transform_keys(&:to_s) })
             .sort_by { |r| [r["modifier"].to_s, r["boost_type"].to_s, r["series"].to_s, r["size"].to_s] }

    File.write(file, JSON.pretty_generate(merged) + "\n")
    puts "Generated #{gen.size} rows / #{gen_modifiers.size} modifiers; kept #{kept.size} existing " \
         "(#{existing.size - kept.size} replaced); total #{merged.size}."
  end

  desc "Sync weapon_skill_data table from data/weapon_skill_data.json (upsert + prune)"
  task load_weapon_skill_data: :environment do
    records = JSON.parse(File.read(Rails.root.join("data", "weapon_skill_data.json")))
    keys = records.map { |r| [r["modifier"], r["boost_type"], r["series"], r["size"]] }.to_set

    records.each do |r|
      d = WeaponSkillDatum.find_or_initialize_by(
        modifier: r["modifier"], boost_type: r["boost_type"], series: r["series"], size: r["size"]
      )
      %w[formula_type sl1 sl10 sl15 sl20 sl25 coefficient max_value aura_boostable].each { |c| d[c] = r[c] }
      d.save!
    end
    pruned = WeaponSkillDatum.all.reject { |d| keys.include?([d.modifier, d.boost_type, d.series, d.size]) }
    pruned.each(&:destroy)
    puts "Loaded #{records.size} rows; pruned #{pruned.size}; total #{WeaponSkillDatum.count}."
  end

  desc "Grid-resolution proof: select each grid weapon's active skill version and resolve it to data/effects. party=<shortcode> for one party, else aggregate over all grid weapons."
  task weapon_skill_resolution: :environment do
    scope = if ENV["party"]
              p = Party.find_by!(shortcode: ENV["party"])
              p.grid_weapons.includes(weapon: { weapon_skills: { weapon_skill_versions: :skill } })
            else
              GridWeapon.includes(weapon: { weapon_skills: { weapon_skill_versions: :skill } })
            end

    total = 0; standard = 0; resolved_data = 0; resolved_effects = 0; unresolved = []
    scope.find_each do |gw|
      next unless gw.weapon
      gw.weapon.weapon_skills.each do |ws|
        v = ws.active_version(uncap_level: gw.uncap_level.to_i, transcendence_step: gw.transcendence_step.to_i)
        next unless v
        total += 1
        next if v.skill_modifier.blank? # unique/unrecognized — no scaling expected
        standard += 1
        if v.weapon_skill_data.exists? then resolved_data += 1
        elsif v.weapon_skill_effects.exists? then resolved_effects += 1
        else unresolved << v.skill_modifier end
      end
    end
    pct = standard.zero? ? 0 : (100.0 * (resolved_data + resolved_effects) / standard).round(1)
    puts "active versions=#{total}  standard=#{standard}  ->data=#{resolved_data}  ->effects=#{resolved_effects}  resolved=#{pct}%"
    puts "unresolved (job/unique): #{unresolved.tally.sort_by { |_, c| -c }.first(15).to_h}" if unresolved.any?
  end

  desc "Build icon->(series,size) map from wiki-source -> data/weapon_skill_icon_map.json"
  task extract_weapon_skill_icon_map: :environment do
    require Rails.root.join("lib/granblue/extractors/weapon_skill_data_extractor")
    skill_dir = wiki_source_dir.join("weapon-skill-types")
    wpn_dir   = wiki_source_dir.join("wpnskill-templates")
    ex = Granblue::Extractors::WeaponSkillDataExtractor.new
    map = {}
    Dir[skill_dir.join("*.wikitext")].sort.each do |f|
      name = File.basename(f, ".wikitext").tr("_", " ")
      text = File.read(f)
      if (m = text.match(/\{\{(WpnSkill[A-Za-z0-9]+)/))
        sub = wpn_dir.join("#{m[1]}.wikitext")
        text += "\n" + File.read(sub) if File.exist?(sub)
      end
      entries = begin
        ex.icon_entries(text, name: name)
      rescue
        []
      end
      map[name] = entries unless entries.empty?
    end
    File.write(Rails.root.join("data", "weapon_skill_icon_map.json"), JSON.pretty_generate(map) + "\n")
    puts "icon map: #{map.size} modifiers, #{map.values.sum(&:size)} entries"
  end
end
