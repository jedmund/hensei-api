# frozen_string_literal: true

module WeaponSkills
  module Build
    module Rows
      # granblue:compare_rows: runs the row compiler over the database's versions and compares
      # the result with today's generated version-linked rows (manually_edited_at nil), on
      # kind, boost type, condition and every value column.
      #
      # Differences are keyed "weapon|position|ordinal|skill name|kind|boost_type|condition"
      # and classified:
      #   classified   listed in CLASSIFICATIONS_PATH (parser / accept, with a reason)
      #   override     the version has a classification override: family_curve now reads
      #                resolved_* (W1's fix), so the answer is allowed to change
      #   notes        a Gameplay Notes row (per_grid_count / specialty_scaled) with no stored
      #                expansion to compile it from
      #   unknown      everything else; the task fails on these
      class Comparison
        CLASSIFICATIONS_PATH = Rails.root.join("data/weapon_skill_parity/compare_rows_classifications.json")
        REPORT_PATH = Rails.root.join("data/weapon_skill_parity/compare_rows_last.json")
        NOTES_KINDS = %w[per_grid_count specialty_scaled].freeze
        DATUM_COLUMNS = DATUM_DEFAULTS.keys.map(&:to_s).freeze
        EFFECT_COLUMNS = EFFECT_DEFAULTS.keys.map(&:to_s).freeze

        attr_reader :differences, :counts

        # weapon_ids: granblue ids; series: weapon series slugs; notes_source: a callable
        # weapon → expanded wikitext or nil (nil = notes not compiled).
        def initialize(weapon_ids: nil, series: nil, notes_source: nil, classifications: self.class.classifications)
          @weapon_ids = weapon_ids
          @series = series
          @notes_source = notes_source
          @classifications = classifications
          @differences = []
          @counts = Hash.new(0)
        end

        def self.classifications
          File.exist?(CLASSIFICATIONS_PATH) ? JSON.parse(File.read(CLASSIFICATIONS_PATH)) : {}
        end

        def run
          weapons = weapon_scope.pluck(:granblue_id, :wiki_raw, :id).to_h { |g, raw, id| [g, [raw.to_s, id]] }
          registry = Registry.from_database
          curation = CurationView.from_database(weapon_granblue_ids: weapons.keys)
          versions = version_scope(weapons.keys).to_a
          today = generated_rows(versions.map(&:id))
          notes_cache = {}

          versions.each do |v|
            ws = v.weapon_skill
            raw, weapon_id = weapons[ws.weapon_granblue_id]
            name = v.skill&.name_en.to_s
            text = Description.text(wiki_raw: raw, position: ws.position, name: name, fallback: v.skill&.description_en)
            version = build_version(v, ws, name, text)
            notes = notes_for(weapon_id, notes_cache)
            rows = Rows.call(version, text: text, registry: registry, curation: curation, notes: notes)
            compare(v, version, rows, today[v.id] || [], notes_compiled: !notes.nil?)
            @counts[:versions] += 1
          end
          self
        end

        def unknown = @differences.select { |d| d["class"] == "unknown" }

        def report
          { "counts" => @counts.sort.to_h,
            "differences" => @differences.sort_by { |d| d["key"] } }
        end

        def write(path = REPORT_PATH)
          File.write(path, "#{JSON.pretty_generate(report)}\n")
        end

        private

        def weapon_scope
          scope = Weapon.all
          scope = scope.where(granblue_id: @weapon_ids) if @weapon_ids.present?
          scope = scope.joins(:weapon_series).where(weapon_series: { slug: @series }) if @series.present?
          scope
        end

        def version_scope(weapon_ids)
          WeaponSkillVersion.joins(:weapon_skill).where(weapon_skills: { weapon_granblue_id: weapon_ids })
                            .includes(:skill, :weapon_skill)
                            .order("weapon_skills.weapon_granblue_id", "weapon_skills.position", :ordinal)
        end

        # The version as the extractor saw it after its own step 1: resolved classification,
        # with the series re-derived from the description unless the overlay pins it.
        def build_version(record, slot, name, text)
          v = record
          series = v.series_override.presence ||
                   (text.present? ? Parser.series_for(text, name) : v.skill_series)
          WeaponSkills::BuildResult::Version.new(
            weapon_granblue_id: slot.weapon_granblue_id, position: slot.position, ordinal: v.ordinal,
            skill_name_en: name, skill_name_jp: v.skill&.name_jp,
            description_en: text, unlock_level: v.unlock_level, min_uncap: v.min_uncap,
            transcendence_stage: v.transcendence_stage,
            skill_modifier: v.resolved_modifier, skill_series: series, skill_size: v.resolved_size
          )
        end

        def notes_for(weapon_id, cache)
          return nil unless @notes_source

          cache.fetch(weapon_id) do
            expanded = @notes_source.call(weapon_id)
            cache[weapon_id] = expanded && GameplayNotes.parse(expanded)
          end
        end

        def generated_rows(version_ids)
          out = Hash.new { |h, k| h[k] = [] }
          { datum: [WeaponSkillDatum, DATUM_COLUMNS], effect: [WeaponSkillEffect, EFFECT_COLUMNS] }
            .each do |kind, (model, columns)|
            model.where(weapon_skill_version_id: version_ids, manually_edited_at: nil).find_each do |r|
              out[r.weapon_skill_version_id] << [kind, normalize(r.attributes.slice(*columns))]
            end
          end
          out
        end

        def compare(record, version, rows, today, notes_compiled:)
          ours = rows.map { |r| [r.kind, normalize(r.attributes.transform_keys(&:to_s))] }
          ours_by = ours.index_by { |kind, attrs| row_key(kind, attrs) }
          today_by = today.index_by { |kind, attrs| row_key(kind, attrs) }
          @counts[:rows_today] += today.size
          @counts[:rows_compiled] += ours.size

          (ours_by.keys | today_by.keys).sort_by(&:to_s).each do |rk|
            mine = ours_by[rk]&.last
            theirs = today_by[rk]&.last
            if mine == theirs
              @counts[:rows_equal] += 1
              next
            end

            change = if mine.nil? then { "missing" => theirs }
                     elsif theirs.nil? then { "added" => mine }
                     else { "fields" => mine.keys.reject { |k| mine[k] == theirs[k] }.to_h { |k| [k, [theirs[k], mine[k]]] } }
                     end
            key = (version.identity + [version.skill_name_en, *rk.first(2), JSON.generate(rk.last)]).join("|")
            klass = classify(key, record, rk, mine || theirs, notes_compiled)
            @counts[:"diff_#{klass}"] += 1
            @differences << { "key" => key, "class" => klass, "reason" => @classifications.dig(key, "reason") }
                            .compact.merge(change)
          end
        end

        def classify(key, record, row_key, attrs, notes_compiled)
          return @classifications.dig(key, "class") if @classifications.key?(key)
          return "notes" if !notes_compiled && row_key.first == "effect" && NOTES_KINDS.include?(attrs["scaling_kind"])
          if row_key.first == "datum" &&
             [record.modifier_override, record.series_override, record.size_override].any?(&:present?)
            return "override"
          end

          "unknown"
        end

        # Row key: the tables' uniqueness scope (modifier is always the skill name).
        def row_key(kind, attrs)
          if kind == :datum
            ["datum", attrs["boost_type"], [attrs["series"], attrs["size"]]]
          else
            ["effect", attrs["boost_type"], [attrs["scaling_kind"], attrs["condition"]]]
          end
        end

        def normalize(attrs)
          attrs.transform_values do |v|
            case v
            when BigDecimal, Float then v.to_f
            when Hash then JSON.parse(JSON.generate(v))
            when Array then v.map(&:to_s)
            else v
            end
          end
        end
      end
    end
  end
end
