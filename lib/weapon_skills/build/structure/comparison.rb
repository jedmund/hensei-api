# frozen_string_literal: true

module WeaponSkills
  module Build
    module Structure
      # granblue:compare_structure: runs the structure compiler over every weapon and compares
      # it with the database's slots and versions.
      #
      # The overlay's structural ops (add_version, remove_version, gate) are applied to the
      # compiler's output first, as the build will. Compared per version identity
      # (weapon, position, ordinal): the skill name, the gate, the derived classification,
      # the icon and the flags.
      #
      # Each difference is keyed "weapon|position|ordinal|skill name|field" and classified:
      #   override    a derived skill_modifier/skill_series/skill_size on a version whose
      #               override (overlay) decides the resolved value
      #   backfill    skill_modifier/skill_size that Rows' family backfill sets from the name
      #   classified  listed in CLASSIFICATIONS_PATH (parser / accept, with a reason)
      #   unknown     everything else; the task fails on these
      # Ops the compiler now makes redundant are reported too.
      class Comparison
        CLASSIFICATIONS_PATH = Rails.root.join("data/weapon_skill_parity/compare_structure_classifications.json")
        REPORT_PATH = Rails.root.join("data/weapon_skill_parity/compare_structure_last.json")
        CURATION_GLOB = Rails.root.join("data/weapon_skill_curation/*.json").to_s
        FIELDS = %w[skill_name_en unlock_level min_uncap transcendence_stage skill_modifier skill_series skill_size
                    multiplier_frame icon main_hand_only mc_only].freeze
        GATE_FIELDS = %w[unlock_level min_uncap transcendence_stage].freeze
        # A derived column whose version carries an override: the overlay decides the
        # resolved value, so the derived one doesn't reach the calculator.
        OVERRIDES = { "skill_modifier" => "modifier_override", "skill_series" => "series_override",
                      "skill_size" => "size_override" }.freeze

        attr_reader :differences, :counts, :redundant_ops, :warnings

        def initialize(weapon_ids: nil, series: nil, store: WeaponSkills::SourceStore::Database.new,
                       classifications: self.class.classifications, ops: self.class.ops)
          @weapon_ids = weapon_ids
          @series = series
          @store = store
          @classifications = classifications
          @ops = ops.group_by { |op| op["weapon"] }
          @differences = []
          @redundant_ops = []
          @warnings = []
          @counts = Hash.new(0)
        end

        def self.classifications
          File.exist?(CLASSIFICATIONS_PATH) ? JSON.parse(File.read(CLASSIFICATIONS_PATH)) : {}
        end

        def self.ops
          Dir[CURATION_GLOB].flat_map { |path| JSON.parse(File.read(path))["ops"] || [] }
        end

        def run
          registry = Rows::Registry.from_database
          weapons = weapon_scope.to_a
          today = database_versions(weapons.map(&:granblue_id))
          Granblue::Parsers::Wiki.offline(store: @store) do
            weapons.each do |weapon|
              _slots, versions, warnings = Structure.call(weapon, store: @store)
              @warnings.concat(warnings)
              ours = apply_ops(weapon.granblue_id, versions.index_by(&:identity))
              compare(weapon, ours, today[weapon.granblue_id] || {}, registry)
              @counts["weapons"] += 1
              @counts["versions"] += ours.size
            end
          end
          self
        end

        def unknown = @differences.select { |d| d["class"] == "unknown" }

        def report
          { "counts" => @counts.sort.to_h,
            "differences" => @differences.sort_by { |d| d["key"] },
            "redundant_ops" => @redundant_ops.sort_by { |o| o.values_at("weapon", "skill").map(&:to_s) },
            "warnings" => @warnings.sort }
        end

        def write(path = REPORT_PATH)
          File.write(path, "#{JSON.pretty_generate(report)}\n")
        end

        private

        def weapon_scope
          scope = Weapon.where(id: WeaponSource.where(kind: "wiki_raw").select(:weapon_id))
                        .or(Weapon.where(granblue_id: WeaponSkill.select(:weapon_granblue_id)))
          scope = scope.where(granblue_id: @weapon_ids) if @weapon_ids.present?
          scope = scope.joins(:weapon_series).where(weapon_series: { slug: @series }) if @series.present?
          scope.order(:granblue_id)
        end

        # { granblue_id => { identity => attributes } }
        def database_versions(granblue_ids)
          WeaponSkillVersion.joins(:weapon_skill, :skill)
                            .where(weapon_skills: { weapon_granblue_id: granblue_ids })
                            .pluck("weapon_skills.weapon_granblue_id", "weapon_skills.position", :ordinal,
                                   "skills.name_en", *(FIELDS - ["skill_name_en"]), *OVERRIDES.values)
                            .each_with_object(Hash.new { |h, k| h[k] = {} }) do |row, out|
            gid, position, ordinal, name, *rest = row
            columns = (FIELDS - ["skill_name_en"]) + OVERRIDES.values
            out[gid][[gid, position, ordinal]] = { "skill_name_en" => name }.merge(columns.zip(rest).to_h)
          end
        end

        # The overlay's structural ops on the compiler's output, keyed by identity. An op the
        # output already satisfies is reported as redundant.
        def apply_ops(gid, versions)
          by_ref = ->(op) { versions.values.find { |v| v.skill_name_en == op["skill"] && v.ordinal == op["ordinal"] } }
          ops = @ops[gid] || []
          ops.select { |op| op["op"] == "remove_version" }.each do |op|
            version = by_ref.call(op) or next(redundant(op))
            versions.delete(version.identity)
          end
          ops.select { |op| op["op"] == "add_version" }.each do |op|
            next redundant(op) if by_ref.call(op)

            identity = [gid, op["position"], op["ordinal"]]
            next if versions.key?(identity)

            versions[identity] = Version.new(weapon_granblue_id: gid, position: op["position"], ordinal: op["ordinal"],
                                             skill_name_en: op["skill"], unlock_level: op["unlock_level"],
                                             min_uncap: op["min_uncap"], transcendence_stage: op["transcendence_stage"] || 0)
            @counts["ops_add_version_applied"] += 1
          end
          ops.select { |op| op["op"] == "gate" }.each do |op|
            version = by_ref.call(op) or next(@counts["ops_gate_unmatched"] += 1)
            attrs = op.slice(*GATE_FIELDS)
            next redundant(op) if attrs.all? { |k, val| version[k] == val }

            attrs.each { |k, val| version[k] = val }
            @counts["ops_gate_applied"] += 1
          end
          versions
        end

        def redundant(entry)
          @redundant_ops << entry.slice("op", "weapon", "skill", "ordinal")
        end

        def compare(weapon, ours, today, registry)
          (ours.keys | today.keys).each do |identity|
            mine = ours[identity]
            theirs = today[identity]
            name = (mine&.skill_name_en || theirs["skill_name_en"]).to_s
            base = "#{identity.join('|')}|#{name}"
            if mine.nil?
              record(weapon, "#{base}|missing", "missing", nil, nil)
            elsif theirs.nil?
              record(weapon, "#{base}|added", "added", nil, gate(mine))
            else
              FIELDS.each do |field|
                ours_value = normalize(mine[field])
                today_value = normalize(theirs[field])
                next if ours_value == today_value

                diff_class = if theirs[OVERRIDES[field]].present? then "override"
                             elsif backfilled?(mine, field, today_value, registry) then "backfill"
                             end
                record(weapon, "#{base}|#{field}", "changed", today_value, ours_value, diff_class)
              end
            end
          end
        end

        def gate(version) = GATE_FIELDS.map { |f| version[f] }

        def normalize(value) = value.is_a?(String) ? value.presence : value

        # Rows backfills a blank family (and its size) from the skill name.
        def backfilled?(version, field, today_value, registry)
          return false unless %w[skill_modifier skill_size].include?(field) && version.skill_modifier.blank?

          text = version.description_en.to_s
          parsed = WeaponSkillDescriptionParser.parse(text, name: version.skill_name_en)
          filled = Rows::Classification.backfill(version, parsed, registry)
          filled[field] == today_value
        rescue StandardError
          false
        end

        def record(weapon, key, kind, today_value, ours_value, diff_class = nil)
          entry = @classifications[key]
          diff_class ||= entry ? entry["class"] : "unknown"
          @counts["diff_#{diff_class}"] += 1
          @differences << { "key" => key, "weapon" => weapon.name_en, "kind" => kind, "today" => today_value,
                            "ours" => ours_value, "class" => diff_class, "reason" => entry&.dig("reason") }.compact
        end

        WeaponSkillDescriptionParser = Granblue::Parsers::WeaponSkillDescriptionParser
        private_constant :WeaponSkillDescriptionParser
      end
    end
  end
end
