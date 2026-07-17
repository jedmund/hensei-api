# frozen_string_literal: true

module Granblue
  module Extractors
    # Imports the wiki's per-family skill templates ({{Weapon Skills/<name>}}) — the
    # source our curves were originally seeded from. Conservative by design: the WsBox
    # header upserts the family registry; the SL-curve tables are parsed into candidate
    # rows and DIFFED against weapon_skill_data. Only rows that are MISSING are written
    # (provenance "wiki_template"); disagreements with existing rows are reported, never
    # applied — golden/manual provenance always wins (#62 phase 4/5).
    class FamilyTemplateImporter
      NAV_FAMILIES = [
        "Abandon", "Aegis", "Apotheosis", "Aramis", "Ars",
        "Arts", "Ascendancy", "Athos", "Auspice", "Bastion",
        "Beast Essence", "Betrayal", "Bladeshield", "Blessing", "Bloodrage",
        "Bloodshed", "Blow", "Celere", "Chain Force", "Charge",
        "Clarity", "Convergence", "Craft", "Crux", "Deathstrike",
        "Demolishment", "Devastation", "Dominion", "Draconic Barrier", "Draconic Fortitude",
        "Draconic Magnitude", "Draconic Progression", "Dual-Edge", "Empowerment", "Encouragement",
        "Enforcement", "Enmity", "Essence", "Excelsior", "Exertion",
        "Fandango", "Fathoms", "Fortified", "Fortitude", "Frailty",
        "Fulgor Elatio", "Fulgor Fortis", "Fulgor Impetus", "Fulgor Sanatio", "Garrison",
        "Glory", "Godblade", "Godflair", "Godheart", "Godshield",
        "Godstrike", "Grace", "Grand Epic", "Haunt", "Healing",
        "Heed", "Heroism", "Honing", "Hunt", "Impalement",
        "Initiation", "Insignia", "Majesty", "Maneuver", "Marvel",
        "Might", "Mystery", "Onslaught", "Pact", "Parity",
        "Persistence", "Plenum", "Porthos", "Precocity", "Preemptive Barrier",
        "Preemptive Blade", "Preemptive Wall", "Primacy", "Progression", "Quenching",
        "Quintessence", "Refuge", "Resolve", "Resonator", "Restraint",
        "Rigor", "Rubell", "Ruination", "Sapience", "Scandere Aggressio",
        "Scandere Arcanum", "Scandere Catena", "Scandere Facultas", "Sentence", "Sephira Maxi",
        "Sephira Soul", "Sephira Tek", "Sovereign", "Spearhead", "Spectacle",
        "Stamina", "Stratagem", "Strike", "Striking Art", "Supremacy",
        "Supremacy: Decimation", "Surge", "Sweep", "Tempering", "Trituration",
        "Trium", "Truce", "True Dragon Barrier", "True Supremacy", "Tyranny",
        "Ultio", "Utopia", "Valuables", "Verity", "Verve",
        "Vitality", "Vivification", "Voltage", "Wrath", "Zenith Art",
        "Zenith Strike"
      ].freeze

      Result = Struct.new(:family, :status, :missing, :mismatches, :skipped, keyword_init: true)

      SIZE_TIERS = {
        "small" => "small", "medium" => "medium", "big" => "big",
        "big ii" => "big_ii", "big2" => "big_ii", "massive" => "massive",
        "unworldly" => "unworldly"
      }.freeze
      SL_HEADER = /!\s*1\s*!!\s*10\s*!!\s*15(?:\s*!!\s*20)?(?:\s*!!\s*25)?/
      SL_COLUMNS = %w[sl1 sl10 sl15 sl20 sl25].freeze

      # Panel boost label (wiki {{Label|…}}) → our boost_type key. Only mapped labels
      # become curve rows; unmapped ones are reported as skipped, never guessed.
      LABEL_TO_BOOST = {
        "might" => "atk", "omega might" => "atk", "ex might" => "atk", "atk" => "atk",
        "hp" => "hp", "def" => "def", "critical" => "critical",
        "da rate" => "da", "ta rate" => "ta",
        "stamina" => "atk", "omega stamina" => "atk", "enmity" => "atk", "omega enmity" => "atk",
        "c.a. dmg" => "ca_dmg", "c.a. dmg cap" => "ca_dmg_cap",
        "c.b. dmg" => "cb_dmg", "c.b. dmg cap" => "cb_dmg_cap",
        "skill dmg cap" => "skill_dmg_cap", "n.a. dmg cap" => "na_dmg_cap",
        "dmg cap" => "dmg_cap", "dmg amp." => "dmg_amp", "heal cap" => "heal_cap",
        "debuff res." => "debuff_res", "counter rate" => "counter_dmg",
        "hp cut" => "hp_cut", "hp dmg" => "hp_dmg", "turn dmg" => "turn_dmg",
        "elem. reduc." => "elem_reduc", "elem. amplify" => "elem_amplify",
        "charge gain" => "charge_gain", "def ignore" => "def_ignore"
      }.freeze

      class << self
        def import(names, apply: false, throttle: 1.0)
          names.map do |name|
            result = import_one(name, apply: apply)
            sleep(throttle)
            result
          rescue StandardError => e
            Result.new(family: name, status: "error: #{e.class}: #{e.message[0..80]}",
                       missing: [], mismatches: [], skipped: [])
          end
        end

        def import_one(name, apply: false)
          raw = fetch_template(name)
          if raw.blank?
            return Result.new(family: name, status: "no_template",
                              missing: [], mismatches: [], skipped: [])
          end

          upsert_family(name, raw)
          candidates, skipped = parse_curves(raw)
          diff(name, candidates, skipped, apply: apply)
        end

        private

        def fetch_template(name)
          require "net/http"
          ua = Rails.application.credentials.wiki_user_agent
          uri = URI("https://gbf.wiki/Template:Weapon_Skills/#{ERB::Util.url_encode(name.tr(' ', '_'))}?action=raw")
          res = Net::HTTP.get_response(uri, { "User-Agent" => ua })
          res.code == "200" ? res.body.to_s.force_encoding("UTF-8").scrub : nil
        end

        # The WsBox header IS the family registry row.
        def upsert_family(name, raw)
          box = raw[/\{\{WsBox(.*?)\n\}\}/m, 1].to_s
          fields = box.scan(/^\|([a-z0-9_]+)=(.*)$/).transform_values { |v| v.strip }
          boosts = fields.keys.grep(/\Aboost\d\z/).sort.filter_map { |k| fields[k].presence }
          stems = {}
          { "" => "normal", "o_" => "omega", "ex_" => "ex" }.each do |prefix, series|
            SIZE_TIERS.each_value.uniq.each do |size|
              key = "#{prefix}#{size.sub('_ii', '2')}"
              stems[series] ||= {}
              stems[series][size] = fields[key] if fields[key].present?
            end
          end
          family = WeaponSkillFamily.find_or_initialize_by(name: name)
          return if family.manually_edited_at.present?

          family.update!(
            aura_boostable: fields["aura_boostable"].blank? ? nil : fields["aura_boostable"] == "yes",
            boosts: boosts, color: fields["color"].presence,
            icon_stems: stems.reject { |_, v| v.empty? }, imported_at: Time.current
          )
        end

        # wsmod tables → candidate curve rows. Row semantics: a wsmod-title header sets
        # the series; the SL header sets which columns exist; wsmod-tier cells set the
        # size (carried across rowspans); wsmod-stat cells set the boost label (carried
        # for single-stat families); the remaining plain cells are the SL values.
        def parse_curves(raw)
          candidates = []
          skipped = []
          series = nil
          columns = []
          size = nil
          stat = nil
          raw.each_line do |line|
            if (title = line[/class="wsmod-title"[^|]*\|(.*)$/, 1])
              series = series_for_title(title)
              size = stat = nil
            elsif line.match?(SL_HEADER)
              columns = line.scan(/\d+/).map { |n| "sl#{n}" }
            elsif (tier = line[/class="wsmod-tier"[^|]*\|\s*([A-Za-z2 ]+?)\s*(?:<|$)/, 1])
              size = SIZE_TIERS[tier.strip.downcase]
            elsif (label = line[/class="wsmod-stat"[^|]*\|\s*\{\{Label\|([^}]+)\}\}/, 1])
              stat = label.strip
            end

            next unless series && size && line.start_with?("|") && line.include?("%")

            values = line.split("||").map { |c| c[/([\d.]+)%/, 1] }
            next if values.compact.empty? || columns.empty?

            boost = LABEL_TO_BOOST[stat.to_s.downcase]
            if boost.nil?
              skipped << { series: series, size: size, stat: stat }
              next
            end
            row = { series: series, size: size, boost_type: boost }
            columns.each_with_index { |col, i| row[col] = values[i]&.to_f }
            candidates << row
          end
          [candidates, skipped.uniq]
        end

        def series_for_title(title)
          t = title.downcase
          return "normal_omega" if t.include?("normal") && t.include?("omega")
          return "taboo" if t.include?("taboo")
          return "omega" if t.include?("omega")
          return "normal" if t.include?("normal")
          return "ex" if t.include?("ex")

          nil
        end

        # Compare candidates with existing canonical rows: fill gaps (apply mode),
        # report disagreements, never overwrite.
        def diff(name, candidates, skipped, apply:)
          missing = []
          mismatches = []
          candidates.each do |cand|
            existing = WeaponSkillDatum.where(weapon_skill_version_id: nil, modifier: name,
                                              size: cand[:size], boost_type: cand[:boost_type])
                                       .find { |d| series_compatible?(d.series, cand[:series]) }
            if existing.nil?
              missing << cand
              next unless apply

              WeaponSkillDatum.create!(
                modifier: name, series: cand[:series], size: cand[:size],
                boost_type: cand[:boost_type], formula_type: "flat", provenance: "wiki_template",
                **cand.slice(*SL_COLUMNS).compact.transform_keys(&:to_sym)
              )
            else
              diffs = SL_COLUMNS.filter_map do |col|
                wiki = cand[col]
                ours = existing.public_send(col)&.to_f
                next if wiki.nil? || ours.nil? || (wiki - ours).abs < 0.005
                # demerit rows store the panel sign (hp_cut -10); the wiki lists magnitude
                next if (wiki - ours.abs).abs < 0.005 && ours.negative?

                "#{col}: wiki=#{wiki} ours=#{ours}#{existing.provenance ? " [#{existing.provenance}]" : ''}"
              end
              if diffs.any?
                mismatches << { series: cand[:series], size: cand[:size],
                                boost_type: cand[:boost_type], diffs: diffs }
              end
            end
          end
          Result.new(family: name, status: "ok", missing: missing,
                     mismatches: mismatches, skipped: skipped)
        end

        def series_compatible?(ours, wiki)
          return true if ours == wiki
          return true if wiki == "normal_omega" && %w[normal omega normal_omega].include?(ours)
          return true if %w[normal omega].include?(wiki) && ours == "normal_omega"

          false
        end
      end
    end
  end
end
