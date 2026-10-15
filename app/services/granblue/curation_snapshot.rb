# frozen_string_literal: true

module Granblue
  # Hand curation of weapon-skill data, as a committable snapshot
  # (data/weapon_skill_curation.json) that every deploy applies.
  #
  # Curation is any row stamped manually_edited_at (effects and data, canonical and
  # version-linked) plus version overrides (overrides_edited_at). July 2026's curation
  # was made in the dev database and never shipped, because only the canonical rows
  # were exported and nothing applied them to prod. Now:
  #
  # - export writes every curated row, keyed by weapon granblue_id + skill name;
  # - sync applies the snapshot: it creates missing rows and updates a row only when
  #   the snapshot's stamp is newer, so a later edit made in prod's admin editor wins.
  #   It never deletes curated rows. To remove a generated row, curate a
  #   suppressed_boosts override; sync deletes uncurated rows of suppressed types.
  # - drift lists curated rows in this database that the committed snapshot lacks.
  class CurationSnapshot
    PATH = Rails.root.join("data/weapon_skill_curation.json")
    EFFECT_COLUMNS = %w[modifier boost_type series scaling_kind value value_unit per_copy_cap total_cap
                        shared_cap_group cap_formula count_basis count_cap condition target_instance depends_on
                        aura_boostable seraphic_affected stacking applies_to battle_interaction notes key_slug
                        frame_rule provenance].freeze
    DATUM_COLUMNS = %w[modifier boost_type series size formula_type sl1 sl10 sl15 sl20 sl25 coefficient
                       max_value aura_boostable provenance].freeze
    OVERRIDE_COLUMNS = %w[modifier_override series_override size_override suppressed_boosts].freeze
    SECTIONS = %w[versions effects data].freeze

    Report = Struct.new(:created, :updated, :skipped_newer, :suppressed, :unmatched, keyword_init: true)

    def self.export(path: PATH)
      File.write(path, "#{JSON.pretty_generate(new.payload)}\n")
    end

    def self.sync(path: PATH, log: $stdout)
      return Report.new(created: 0, updated: 0, skipped_newer: 0, suppressed: 0, unmatched: []) unless File.exist?(path)

      new.sync(JSON.parse(File.read(path)), log: log)
    end

    # → { "missing" => [rows curated here but absent from the snapshot],
    #     "changed" => [rows whose values differ], "unapplied" => [snapshot rows not here] }
    def self.drift(path: PATH)
      committed = File.exist?(path) ? JSON.parse(File.read(path)) : {}
      new.drift(committed)
    end

    def payload
      {
        "_generated" => "Hand-curated weapon-skill rows, exported by rake granblue:export_weapon_skill_curation " \
                        "and applied on every deploy by granblue:sync_weapon_skill_curation.",
        "versions" => versions_payload,
        "effects" => rows_payload(WeaponSkillEffect, EFFECT_COLUMNS),
        "data" => rows_payload(WeaponSkillDatum, DATUM_COLUMNS)
      }
    end

    def sync(snapshot, log:)
      @report = Report.new(created: 0, updated: 0, skipped_newer: 0, suppressed: 0, unmatched: [])
      ActiveRecord::Base.transaction do
        Array(snapshot["versions"]).each { |row| sync_version(row) }
        Array(snapshot["effects"]).each { |row| sync_row(WeaponSkillEffect, row, effect_identity(row)) }
        Array(snapshot["data"]).each { |row| sync_row(WeaponSkillDatum, row, datum_identity(row)) }
      end
      @report.unmatched.each { |row| log.puts "curation sync: no match for #{describe(row)}" }
      log.puts "curation sync: #{@report.created} created, #{@report.updated} updated, " \
               "#{@report.skipped_newer} kept (newer here), #{@report.suppressed} suppressed rows removed, " \
               "#{@report.unmatched.size} unmatched"
      @report
    end

    def drift(committed)
      current = payload
      SECTIONS.each_with_object({ "missing" => [], "changed" => [], "unapplied" => [] }) do |section, out|
        mine = index(current[section], section)
        theirs = index(Array(committed[section]), section)
        mine.each do |key, row|
          if !theirs.key?(key) then out["missing"] << row
          elsif comparable(theirs[key]) != comparable(row) then out["changed"] << row
          end
        end
        theirs.each { |key, row| out["unapplied"] << row unless mine.key?(key) }
      end
    end

    private

    # ---- export ---------------------------------------------------------------

    def versions_payload
      WeaponSkillVersion.includes(:skill, :weapon_skill).where.not(overrides_edited_at: nil)
                        .map { |v| version_ref(v).merge(serialize(v, OVERRIDE_COLUMNS)).merge(stamp(v.overrides_edited_at)) }
                        .sort_by { |row| [row["weapon"].to_s, row["skill"].to_s, row["ordinal"].to_i] }
    end

    def rows_payload(model, columns)
      curated = model.where.not(manually_edited_at: nil).includes(weapon_skill_version: %i[skill weapon_skill])
      # rows still pointing at a deleted version are dead (the calculator never reads them)
      rows = curated.reject { |row| row.weapon_skill_version_id && row.weapon_skill_version.nil? }.map do |row|
        ref = row.weapon_skill_version ? version_ref(row.weapon_skill_version) : {}
        ref.merge(serialize(row, columns)).merge(stamp(row.manually_edited_at))
      end
      rows.sort_by do |row|
        [row["weapon"].to_s, row["skill"].to_s, row["modifier"].to_s, row["boost_type"].to_s,
         sorted(row["condition"] || {}).to_json]
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

    def find_version(row)
      return nil unless row["weapon"]

      scope = WeaponSkillVersion.joins(:skill, :weapon_skill)
                                .where(weapon_skills: { weapon_granblue_id: row["weapon"] }, skills: { name_en: row["skill"] })
      scope.size > 1 ? scope.find_by(ordinal: row["ordinal"]) : scope.first
    end

    def sync_version(row)
      version = find_version(row) or return @report.unmatched << row
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

      find_version(row)&.id || :unmatched
    end

    # ---- drift ----------------------------------------------------------------

    def index(rows, section)
      rows.index_by do |row|
        base = [row["weapon"], row["skill"], row["ordinal"]]
        case section
        when "versions" then base
        when "effects" then base + [row["modifier"], row["boost_type"], row["key_slug"], sorted(row["condition"] || {}).to_json]
        else base + [row["modifier"], row["boost_type"], row["series"], row["size"]]
        end
      end
    end

    def sorted(value)
      value.is_a?(Hash) ? value.sort.to_h.transform_values { |v| sorted(v) } : value
    end

    # Stamps only order edits; a row whose values match is in sync.
    def comparable(row)
      row.except("edited_at").transform_values { |v| v.is_a?(Integer) ? v.to_f : v }
    end

    def describe(row)
      [row["weapon"], row["skill"], row["modifier"], row["boost_type"]].compact.join(" / ")
    end
  end
end
