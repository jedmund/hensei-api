# frozen_string_literal: true

require "net/http"

namespace :granblue do
  desc "Development only: rebuild a public granblue.team party in this database from the production API, " \
       "so a golden panel reference can validate against it. shortcode=XXXXXX [api=https://api.granblue.team/v1]"
  task import_golden_party: :environment do
    abort "import_golden_party only runs in development" unless Rails.env.development?

    shortcode = ENV.fetch("shortcode") { abort "shortcode=XXXXXX is required" }
    api = ENV.fetch("api", "https://api.granblue.team/v1")
    response = Net::HTTP.get_response(URI("#{api}/parties/#{shortcode}"))
    abort "#{shortcode}: HTTP #{response.code} (is the party public?)" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    data = data["party"] if data.key?("party")
    find = ->(model, ref) { ref && model.find_by(granblue_id: ref["granblue_id"].to_s) }

    ActiveRecord::Base.transaction do
      Party.where(shortcode: shortcode).destroy_all
      party = Party.new(name: data["name"].presence || shortcode, element: data["element"], extra: data["extra"],
                        job: find.call(Job, data["job"]), raid: data["raid"] && Raid.find_by(id: data.dig("raid", "id")),
                        visibility: 1)
      party.save!(validate: false)
      party.update_column(:shortcode, shortcode)

      Array(data["weapons"]).each do |w|
        weapon = find.call(Weapon, w["weapon"]) or abort "unknown weapon #{w.dig('weapon', 'name', 'en')}"
        keys = Array(w["weapon_keys"]).map { |k| WeaponKey.find_by!(slug: k["slug"]).id }
        ax = Array(w["ax"])
        GridWeapon.new({
          party: party, weapon: weapon, position: w["position"], mainhand: w["mainhand"] || w["position"] == -1,
          uncap_level: w["uncap_level"], transcendence_step: w["transcendence_step"], element: w["element"],
          exorcism_level: w["exorcism_level"], skill_level: w["skill_level"],
          awakening_id: w.dig("awakening", "type", "id"), awakening_level: w.dig("awakening", "level"),
          weapon_key1_id: keys[0], weapon_key2_id: keys[1], weapon_key3_id: keys[2], weapon_key4_id: keys[3],
          ax_modifier1_id: ax.dig(0, "modifier", "id"), ax_strength1: ax.dig(0, "strength"),
          ax_modifier2_id: ax.dig(1, "modifier", "id"), ax_strength2: ax.dig(1, "strength"),
          befoulment_modifier_id: w.dig("befoulment", "modifier", "id"), befoulment_strength: w.dig("befoulment", "strength"),
          befoulment_permeation: w.dig("befoulment", "permeation")
        }.compact).save!(validate: false) # nil would override the column defaults
      end
      Array(data["summons"]).each do |s|
        summon = find.call(Summon, s["summon"]) or abort "unknown summon #{s.dig('summon', 'name', 'en')}"
        GridSummon.new({ party: party, summon: summon, position: s["position"], main: s["main"], friend: s["friend"],
                         quick_summon: s["quick_summon"], uncap_level: s["uncap_level"],
                         transcendence_step: s["transcendence_step"] }.compact).save!(validate: false)
      end
      Array(data["characters"]).each do |c|
        character = find.call(Character, c["character"]) or abort "unknown character #{c.dig('character', 'name', 'en')}"
        GridCharacter.new({ party: party, character: character, position: c["position"],
                            uncap_level: c["uncap_level"] || 5, transcendence_step: c["transcendence_step"],
                            perpetuity: c["perpetuity"] }.compact).save!(validate: false)
      end
      Granblue::GoldenFixture.apply_adjustments(party)
      puts "#{shortcode}: #{party.weapons.count} weapons, #{party.summons.count} summons, " \
           "#{party.characters.count} characters, job #{party.job&.name_en || 'none'}"
    end
  end

  desc "Write spec/fixtures/goldens/<shortcode>.json: a golden party plus every catalogue row the calculator " \
       "reads for its panel references. shortcode=XXXXXX (default: every existing fixture)"
  task export_golden_fixture: :environment do
    shortcodes = ENV["shortcode"].present? ? [ENV["shortcode"]] : Granblue::GoldenFixture.shortcodes
    abort "shortcode=XXXXXX is required (no fixtures yet)" if shortcodes.empty?

    FileUtils.mkdir_p(Granblue::GoldenFixture::DIR)
    shortcodes.each do |shortcode|
      fixture = Granblue::GoldenFixture.write(shortcode)
      rows = fixture["tables"].values.sum(&:size)
      puts "#{shortcode}: #{rows} rows in #{fixture['tables'].size} tables, " \
           "references #{fixture['references'].join(', ').presence || 'none'}"
    end
  end

  desc "Load spec/fixtures/goldens/<shortcode>.json into this database. shortcode=XXXXXX " \
       "[mode=party|missing] (party: party rows only, the catalogue must hold what they use; " \
       "missing: also add the fixture's catalogue rows this database lacks)"
  task import_golden_fixture: :environment do
    shortcode = ENV.fetch("shortcode") { abort "shortcode=XXXXXX is required" }
    mode = ENV.fetch("mode", "party").to_sym
    abort "mode must be party or missing" unless %i[party missing].include?(mode)

    party = Granblue::GoldenFixture.load(shortcode, mode: mode)
    puts "#{shortcode}: #{party.weapons.count} weapons, #{party.summons.count} summons, #{party.characters.count} characters"
  rescue Granblue::GoldenFixture::Error => e
    abort e.message
  end

  desc "Load every golden fixture's party into this database (party rows only; used by bin/setup-pipeline-db)"
  task import_golden_fixtures: :environment do
    Granblue::GoldenFixture.shortcodes.each do |shortcode|
      party = Granblue::GoldenFixture.load(shortcode, mode: :party)
      puts "#{shortcode}: loaded (#{party.weapons.count} weapons)"
    rescue Granblue::GoldenFixture::Error => e
      warn "#{shortcode}: skipped - #{e.message}"
    end
  end
end
