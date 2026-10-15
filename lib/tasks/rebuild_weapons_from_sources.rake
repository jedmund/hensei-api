# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Rebuild weapons' skills from stored sources (granblue:fetch_weapon_sources first). Never
    fetches from the wiki. Dry run by default: prints the parity diff and rolls back.

    Groups:
      misrouted  series-template pages ({{Weapon/Common/…}}) whose skills were parsed
                 structurally because "s1_desc=" matched inside "|jps1_desc=" (#537)
      skillless  SSR weapons with a stored page but no skills

    Usage:
      bin/rails granblue:rebuild_weapons_from_sources                     # misrouted + skillless, dry run
      bin/rails granblue:rebuild_weapons_from_sources group=misrouted
      bin/rails granblue:rebuild_weapons_from_sources ids=1040415000,...
      bin/rails granblue:rebuild_weapons_from_sources write=true
  DESC
  task rebuild_weapons_from_sources: :environment do
    ActiveRecord::Base.logger = nil
    write = ENV["write"] == "true"
    groups = ENV.fetch("group", "misrouted,skillless").split(",").map(&:strip)
    ids = ENV["ids"].presence&.split(",")&.map(&:strip)

    english = Granblue::Extractors::ExpandedWeaponSkillImporter::ENGLISH_S1_DESC_SQL
    scopes = {
      "misrouted" => -> { Weapon.where("wiki_raw LIKE ? AND wiki_raw ILIKE ? AND wiki_raw !~ ?", "%{{Weapon/Common/%", "%s1_desc=%", english) },
      "skillless" => -> { Weapon.left_joins(:weapon_skills).where(weapon_skills: { id: nil }, rarity: 3).where.not(wiki_raw: [nil, ""]) }
    }
    unknown = groups - scopes.keys
    abort "unknown group=#{unknown.join(',')} (#{scopes.keys.join(', ')})" if unknown.any? && ids.nil?

    weapons = ids ? Weapon.where(granblue_id: ids).to_a : groups.flat_map { |g| scopes.fetch(g).call.to_a }.uniq
    unstored = weapons.reject { |w| WeaponSource.exists?(weapon_id: w.id, kind: "wiki_raw") }
    if unstored.any?
      puts "#{weapons.size} weapons; #{unstored.size} without stored sources (skipped): " \
           "#{unstored.map(&:name_en).join(', ')}"
    end
    weapons -= unstored
    puts "Rebuilding #{weapons.size} weapons from stored sources (#{write ? 'write' : 'dry run'})…"

    before = WeaponSkills::ParitySnapshot.capture
    results = Hash.new { |h, k| h[k] = [] }
    after = nil
    Granblue::Parsers::Wiki.offline do
      ActiveRecord::Base.transaction do
        weapons.each do |w|
          Granblue::EntityReparser.new(w, refetch: false).reparse
          results[w.weapon_skills.reload.any? ? :ok : :empty] << w.name_en
        rescue StandardError => e
          results[:failed] << "#{w.name_en}: #{e.class}: #{e.message.to_s[0, 100]}"
        end
        after = WeaponSkills::ParitySnapshot.capture
        raise ActiveRecord::Rollback unless write
      end
    end

    puts "ok=#{results[:ok].size} empty=#{results[:empty].size} failed=#{results[:failed].size}"
    (results[:empty] + results[:failed]).each { |line| puts "  - #{line}" }
    diff = WeaponSkills::ParitySnapshot.diff(before, after)
    WeaponSkills::ParityReport.new(diff, group: "series").print
  end
end
