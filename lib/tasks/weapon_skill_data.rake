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

    # Skills whose wiki table the standard SL-column parser can't read (e.g. Abandon's
    # "per Turn / After 10 Turns" two-column layout). Their rows in
    # data/weapon_skill_data.json are hand-curated and kept, not regenerated.
    manual = %w[Abandon].freeze

    gen = []
    Dir[skill_dir.join("*.wikitext")].sort.each do |f|
      name = File.basename(f, ".wikitext").tr("_", " ")
      next if manual.include?(name)

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

  desc "Backfill null weapon-skill version sizes from the (deduped) skill description (order-independent)"
  task backfill_weapon_skill_sizes: :environment do
    re = /\b(unworldly|massive|big|medium|small)\b/i
    n = 0
    WeaponSkillVersion.where(skill_size: nil).where.not(skill_modifier: nil).includes(:skill).find_each do |v|
      name = v.skill&.name_en.to_s
      sz = v.skill&.description_en.to_s[re, 1]&.downcase or next
      sz = "big_ii" if sz == "big" && name =~ /\bII\b/ && name !~ /\bIII\b/
      v.update_column(:skill_size, sz)
      n += 1
    end
    puts "backfilled #{n} version sizes from skill descriptions"
  end

  desc "Validate each weapon skill version's derived size against its description's stated keyword"
  task validate_weapon_skill_sizes: :environment do
    re = /\b(unworldly|massive|big|medium|small)\b/i
    norm = ->(x) { x.to_s == "big_ii" ? "big" : x.to_s } # the description says "Big" for big_ii
    total = 0
    ok = 0
    mismatch = Hash.new(0)
    WeaponSkillVersion.where.not(skill_modifier: nil).includes(:skill).find_each do |v|
      ds = v.skill&.description_en.to_s[re, 1]&.downcase
      next unless ds
      total += 1
      if norm.call(v.skill_size) == ds
        ok += 1
      else
        mismatch["#{v.skill_modifier}: size=#{v.skill_size || 'nil'} desc=#{ds}"] += 1
      end
    end
    pct = total.zero? ? 0 : (100.0 * ok / total).round(1)
    puts "versions whose description states a size: #{total}; derived matches: #{ok} (#{pct}%); mismatch: #{mismatch.values.sum}"
    mismatch.sort_by { |_, c| -c }.first(15).each { |k, c| puts "  #{k} (#{c})" }
  end
end
