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
      puts "#{shortcode}: #{party.weapons.count} weapons, #{party.summons.count} summons, " \
           "#{party.characters.count} characters, job #{party.job&.name_en || 'none'}"
    end
  end
end
