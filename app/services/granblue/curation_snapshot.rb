# frozen_string_literal: true

module Granblue
  # Hand curation of weapon-skill data, as a committed overlay that every deploy
  # applies (docs/weapon-skill-curation.md, docs/weapon-skill-pipeline/overlay-v2.md).
  #
  # The overlay lives in data/weapon_skill_curation/: one file per weapon series, plus
  # _canonical.json for canonical rows. It holds
  # - curated rows (stamped manually_edited_at) and version overrides (overrides_edited_at);
  # - structural ops (remove_version, add_version, gate, description), which exist only
  #   in the files: the database has no record that a value came from an op.
  #
  # - export rewrites the rows and overrides from this database, keeps every op, and
  #   files each entry under its weapon's series;
  # - sync validates every file first (a bad file aborts before anything is written),
  #   then in one transaction applies the ops, the overrides and the rows. Rows are
  #   created when missing and updated only when the snapshot's stamp is newer, so a
  #   later edit made in prod's admin editor wins. It never deletes curated rows. To
  #   remove a generated row, curate a suppressed_boosts override.
  # - drift lists curation in this database that the files lack, and ops not applied here.
  #
  # The v1 single file (data/weapon_skill_curation.json) is still read while it exists;
  # export and granblue:split_weapon_skill_curation replace it.
  class CurationSnapshot
    DIR = Rails.root.join("data/weapon_skill_curation")
    PENDING_DIR = DIR.join("pending")
    LEGACY_PATH = Rails.root.join("data/weapon_skill_curation.json")
    EFFECT_COLUMNS = %w[modifier boost_type series scaling_kind value value_unit per_copy_cap total_cap
                        shared_cap_group cap_formula count_basis count_cap condition target_instance depends_on
                        aura_boostable seraphic_affected stacking applies_to battle_interaction notes key_slug
                        frame_rule provenance].freeze
    DATUM_COLUMNS = %w[modifier boost_type series size formula_type sl1 sl10 sl15 sl20 sl25 coefficient
                       max_value aura_boostable provenance].freeze
    OVERRIDE_COLUMNS = %w[modifier_override series_override size_override suppressed_boosts].freeze
    ROW_SECTIONS = %w[versions effects data].freeze

    Report = Struct.new(:created, :updated, :skipped_newer, :suppressed, :unmatched,
                        :ops_applied, :ops_satisfied, :ops_skipped, keyword_init: true) do
      def changed? = (created + updated + suppressed + ops_applied).positive?
    end

    def self.load(dir: DIR, legacy_path: LEGACY_PATH)
      Overlay.load(dir: dir, legacy_path: legacy_path)
    end

    def self.export(dir: DIR, legacy_path: LEGACY_PATH)
      ops = load(dir: dir, legacy_path: legacy_path).entries("ops")
      Layout.new(dir).write(new.payload.merge("ops" => ops))
      FileUtils.rm_f(legacy_path)
    end

    def self.sync(dir: DIR, legacy_path: LEGACY_PATH, log: $stdout)
      new.sync(load(dir: dir, legacy_path: legacy_path).to_h, log: log)
    end

    # → { "missing" => [curated here, absent from the files], "changed" => [values differ],
    #     "unapplied" => [file entries or ops this database doesn't reflect] }
    def self.drift(dir: DIR, legacy_path: LEGACY_PATH)
      new.drift(load(dir: dir, legacy_path: legacy_path).to_h)
    end

    # Moves the v1 file and pending/ fragments into the per-series layout. It works from
    # the files alone (the database only says which series a weapon is in), so it can be
    # re-run after anyone adds a fragment. → { file name => entry count }
    def self.split(dir: DIR, legacy_path: LEGACY_PATH, pending_dir: PENDING_DIR)
      sections = load(dir: dir, legacy_path: legacy_path).to_h
      Overlay.fold(sections, Overlay.load(dir: pending_dir).to_h)
      docs = Layout.new(dir).write(sections)
      FileUtils.rm_f(legacy_path)
      Dir.glob(File.join(pending_dir.to_s, "*.json")).each { |path| FileUtils.rm_f(path) }
      docs.transform_values { |doc| Overlay::SECTIONS.sum { |section| doc[section].size } }
    end

    # The overlay's view of each version, for the row compiler.
    def self.view(dir: DIR, legacy_path: LEGACY_PATH)
      View.new(load(dir: dir, legacy_path: legacy_path))
    end

    # A version reference (weapon granblue_id, skill name, ordinal) → the version. The
    # ordinal decides only between same-named versions on one weapon.
    def self.find_version(ref)
      return nil unless ref["weapon"]

      scope = WeaponSkillVersion.joins(:skill, :weapon_skill)
                                .where(weapon_skills: { weapon_granblue_id: ref["weapon"] }, skills: { name_en: ref["skill"] })
      scope.size > 1 ? scope.find_by(ordinal: ref["ordinal"]) : scope.first
    end

    # Curation in this database, by section (no ops: those live only in the files).
    def payload
      {
        "versions" => versions_payload,
        "effects" => rows_payload(WeaponSkillEffect, EFFECT_COLUMNS),
        "data" => rows_payload(WeaponSkillDatum, DATUM_COLUMNS)
      }
    end

    def sync(overlay, log:)
      @report = Report.new(created: 0, updated: 0, skipped_newer: 0, suppressed: 0, unmatched: [],
                           ops_applied: 0, ops_satisfied: 0, ops_skipped: 0)
      ActiveRecord::Base.transaction do
        apply_ops(Array(overlay["ops"]))
        Array(overlay["versions"]).each { |row| sync_version(row) }
        Array(overlay["effects"]).each { |row| sync_row(WeaponSkillEffect, row, effect_identity(row)) }
        Array(overlay["data"]).each { |row| sync_row(WeaponSkillDatum, row, datum_identity(row)) }
      end
      log_report(log)
      @report
    end

    def drift(overlay)
      current = payload
      out = { "missing" => [], "changed" => [], "unapplied" => [] }
      ROW_SECTIONS.each do |section|
        mine = current[section].index_by { |row| Overlay.identity(section, row) }
        theirs = Array(overlay[section]).index_by { |row| Overlay.identity(section, row) }
        mine.each do |key, row|
          if !theirs.key?(key) then out["missing"] << row
          elsif comparable(theirs[key]) != comparable(row) then out["changed"] << row
          end
        end
        theirs.each { |key, row| out["unapplied"] << row unless mine.key?(key) }
      end
      ops = Ops.new
      out["unapplied"].concat(Array(overlay["ops"]).reject { |op| ops.satisfied?(op) })
      out
    end

    def self.describe(entry)
      [entry["op"], entry["weapon"], entry["skill"], entry["modifier"], entry["boost_type"]].compact.join(" / ")
    end

    private

    # ---- export ---------------------------------------------------------------

    def versions_payload
      WeaponSkillVersion.includes(:skill, :weapon_skill).where.not(overrides_edited_at: nil).map do |v|
        overrides = serialize(v, OVERRIDE_COLUMNS)
        # A stamped version with every override cleared is still curation ("no overrides").
        overrides = { "suppressed_boosts" => [] } if overrides.empty?
        version_ref(v).merge(overrides).merge(stamp(v.overrides_edited_at))
      end
    end

    def rows_payload(model, columns)
      curated = model.where.not(manually_edited_at: nil).includes(weapon_skill_version: %i[skill weapon_skill])
      # rows still pointing at a deleted version are dead (the calculator never reads them)
      curated.reject { |row| row.weapon_skill_version_id && row.weapon_skill_version.nil? }.map do |row|
        ref = row.weapon_skill_version ? version_ref(row.weapon_skill_version) : {}
        ref.merge(serialize(row, columns)).merge(stamp(row.manually_edited_at))
      end
    end

    def version_ref(version)
      { "weapon" => version.weapon_skill.weapon_granblue_id, "skill" => version.skill.name_en,
        "ordinal" => version.ordinal }
    end

    def serialize(record, columns)
      columns.each_with_object({}) do |column, out|
        value = record[column]
        next if value.nil? || value == [] || (value == {} && column != "condition")

        out[column] = value.is_a?(BigDecimal) ? value.to_f : value
      end
    end

    def stamp(time)
      { "edited_at" => time.utc.iso8601 }
    end

    # ---- sync -----------------------------------------------------------------

    def apply_ops(ops)
      applier = Ops.new
      ops.each_with_index.sort_by { |op, i| [Overlay::OP_ORDER.index(op["op"]), i] }.each do |op, _|
        case applier.apply(op)
        when :applied then @report.ops_applied += 1
        when :satisfied then @report.ops_satisfied += 1
        when :skipped then @report.ops_skipped += 1
        else @report.unmatched << op
        end
      end
    end

    def sync_version(row)
      version = self.class.find_version(row) or return @report.unmatched << row
      edited_at = Time.iso8601(row["edited_at"])
      if version.overrides_edited_at && version.overrides_edited_at.to_i >= edited_at.to_i
        @report.skipped_newer += 1
      else
        attrs = OVERRIDE_COLUMNS.index_with { |c| row[c] }
        attrs["suppressed_boosts"] ||= []
        version.update!(attrs.merge("overrides_edited_at" => edited_at))
        @report.updated += 1
      end
      remove_suppressed(version)
    end

    def remove_suppressed(version)
      types = Array(version.suppressed_boosts)
      return if types.empty?

      @report.suppressed += WeaponSkillEffect.where(weapon_skill_version_id: version.id, boost_type: types,
                                                    manually_edited_at: nil).delete_all
      @report.suppressed += WeaponSkillDatum.where(weapon_skill_version_id: version.id, boost_type: types,
                                                   manually_edited_at: nil).delete_all
    end

    def sync_row(model, row, identity)
      return @report.unmatched << row unless identity

      columns = model == WeaponSkillEffect ? EFFECT_COLUMNS : DATUM_COLUMNS
      edited_at = Time.iso8601(row["edited_at"])
      attrs = columns.index_with { |c| row[c] }
      attrs["condition"] ||= {} if model == WeaponSkillEffect
      attrs["depends_on"] ||= [] if model == WeaponSkillEffect
      record = model.find_by(identity)
      if record.nil?
        model.create!(attrs.compact.merge(identity).merge("manually_edited_at" => edited_at))
        @report.created += 1
      elsif record.manually_edited_at && record.manually_edited_at.to_i >= edited_at.to_i
        @report.skipped_newer += 1
      else
        record.update!(attrs.merge("manually_edited_at" => edited_at))
        @report.updated += 1
      end
    end

    def effect_identity(row)
      version_id = version_id_for(row)
      return nil if version_id == :unmatched

      { "weapon_skill_version_id" => version_id, "modifier" => row["modifier"], "boost_type" => row["boost_type"],
        "key_slug" => row["key_slug"], "condition" => row["condition"] || {} }
    end

    def datum_identity(row)
      version_id = version_id_for(row)
      return nil if version_id == :unmatched

      { "weapon_skill_version_id" => version_id, "modifier" => row["modifier"], "boost_type" => row["boost_type"],
        "series" => row["series"], "size" => row["size"] }
    end

    def version_id_for(row)
      return :unmatched if row["weapon"].nil? && row["skill"] # never fall back to a canonical row
      return nil unless row["weapon"]

      self.class.find_version(row)&.id || :unmatched
    end

    def log_report(log)
      @report.unmatched.each { |entry| log.puts "curation sync: no match for #{self.class.describe(entry)}" }
      log.puts "curation sync: #{@report.ops_applied} ops applied (#{@report.ops_satisfied} already in place, " \
               "#{@report.ops_skipped} waiting for columns), #{@report.created} created, #{@report.updated} updated, " \
               "#{@report.skipped_newer} kept (newer here), #{@report.suppressed} suppressed rows removed, " \
               "#{@report.unmatched.size} unmatched"
    end

    # ---- drift ----------------------------------------------------------------

    # Stamps only order edits; a row whose values match is in sync.
    def comparable(row)
      row.except("edited_at").transform_values { |v| v.is_a?(Integer) ? v.to_f : v }
    end
  end
end
