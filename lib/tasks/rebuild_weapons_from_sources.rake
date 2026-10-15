# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Rebuild weapons' skills from stored sources (granblue:fetch_weapon_sources first) with the
    weapon-skill build. Never fetches from the wiki. Dry run by default: builds in a rolled-back
    transaction and prints the parity diff by series (granblue:build_weapon_skills mode=shadow).

    Groups:
      misrouted  series-template pages ({{Weapon/Common/…}}) whose wikitext also has a
                 "|jps1_desc=" line (#537)
      skillless  SSR weapons with a stored page but no skills

    Usage:
      bin/rails granblue:rebuild_weapons_from_sources                     # misrouted + skillless, dry run
      bin/rails granblue:rebuild_weapons_from_sources group=misrouted
      bin/rails granblue:rebuild_weapons_from_sources ids=1040415000,...
      bin/rails granblue:rebuild_weapons_from_sources write=true
  DESC
  task rebuild_weapons_from_sources: :environment do
    ActiveRecord::Base.logger = nil
    groups = ENV.fetch("group", "misrouted,skillless").split(",").map(&:strip)
    ids = ENV["ids"].presence&.split(",")&.map(&:strip)

    english_s1_desc = '(^|\n)\|[[:space:]]*s1_desc[[:space:]]*=' # "|jps1_desc=" doesn't match
    scopes = {
      "misrouted" => lambda {
        Weapon.where("wiki_raw LIKE ? AND wiki_raw ILIKE ? AND wiki_raw !~ ?", "%{{Weapon/Common/%", "%s1_desc=%",
                     english_s1_desc)
      },
      "skillless" => lambda {
        Weapon.left_joins(:weapon_skills).where(weapon_skills: { id: nil }, rarity: 3).where.not(wiki_raw: [nil, ""])
      }
    }
    unknown = groups - scopes.keys
    abort "unknown group=#{unknown.join(',')} (#{scopes.keys.join(', ')})" if unknown.any? && ids.nil?

    ids ||= groups.flat_map { |g| scopes.fetch(g).call.pluck(:granblue_id) }.uniq
    abort "no weapons selected" if ids.empty?

    summary = WeaponSkills::Build::Runner.new(mode: ENV["write"] == "true" ? "write" : "shadow", ids: ids,
                                              all: true).call
    exit(1) if summary.failed.positive?
  end
end
