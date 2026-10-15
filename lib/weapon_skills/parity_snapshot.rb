# frozen_string_literal: true

module WeaponSkills
  # The parity reference: every skill version's RESOLVED rows, exactly as the calculator
  # reads them (WeaponSkillVersion#weapon_skill_data / #weapon_skill_effects), plus the
  # key-scoped effects. The pipeline must reproduce the committed baseline before anything
  # changes on purpose; a PR that changes data on purpose refreshes the baseline so the
  # diff is reviewed.
  #
  # Version key: "weapon_granblue_id|position|ordinal|skill_name".
  class ParitySnapshot
    BASELINE_PATH = Rails.root.join("data/weapon_skill_parity/baseline.json")
    LAST_DIFF_PATH = Rails.root.join("data/weapon_skill_parity/last_diff.json")
    FIELDS = %w[gate frame data effects].freeze

    # Every column the calculator can read; bookkeeping columns are left out. The lists are
    # recorded in the snapshot's meta, so a schema change shows as a format mismatch.
    BOOKKEEPING = %w[id created_at updated_at notes weapon_skill_version_id manually_edited_at provenance].freeze

    def self.data_columns = WeaponSkillDatum.column_names - BOOKKEEPING
    def self.effect_columns = WeaponSkillEffect.column_names - BOOKKEEPING

    def self.capture(meta: {})
      new.capture(meta: meta)
    end

    def capture(meta: {})
      { "meta" => meta.merge("captured_at" => Time.current.utc.iso8601,
                             "columns" => { "data" => self.class.data_columns, "effects" => self.class.effect_columns }),
        "versions" => versions, "keys" => keys }
    end

    # → { changed: [{key, fields: {field => [before, after]}}], missing: [keys], added: [keys], keys: … }
    def self.diff(before, after)
      columns = [before, after].map { |snap| snap.dig("meta", "columns") }
      if columns.uniq.size > 1
        raise ArgumentError, "snapshot columns differ (#{columns.map(&:inspect).join(' vs ')}); " \
                             "refresh the baseline with write=true in the PR that changes the schema"
      end

      b = before.fetch("versions")
      a = after.fetch("versions")
      changed = (b.keys & a.keys).filter_map do |key|
        fields = FIELDS.each_with_object({}) { |f, h| h[f] = [b[key][f], a[key][f]] if b[key][f] != a[key][f] }
        { "key" => key, "fields" => fields } if fields.any?
      end
      bk = before.fetch("keys", {})
      ak = after.fetch("keys", {})
      key_changes = (bk.keys | ak.keys).sort.filter_map do |slug|
        { "key_slug" => slug, "before" => bk[slug], "after" => ak[slug] } if bk[slug] != ak[slug]
      end
      { "changed" => changed, "missing" => (b.keys - a.keys).sort, "added" => (a.keys - b.keys).sort,
        "keys" => key_changes }
    end

    def self.empty_diff?(diff)
      %w[changed missing added keys].all? { |k| diff[k].empty? }
    end

    # One line per version (and per key), so the baseline stays small and a refresh diffs
    # as one changed line per changed version. Any other section is written as one line.
    def self.write(snapshot, path = BASELINE_PATH)
      FileUtils.mkdir_p(File.dirname(path))
      sections = snapshot.map do |name, value|
        body = if value.is_a?(Hash) && %w[versions keys].include?(name)
                 entries = value.map { |key, entry| "    #{JSON.generate(key)}: #{JSON.generate(entry)}" }
                 entries.empty? ? "{}" : "{\n#{entries.join(",\n")}\n  }"
               else
                 JSON.generate(value)
               end
        "  #{JSON.generate(name)}: #{body}"
      end
      File.write(path, "{\n#{sections.join(",\n")}\n}\n")
    end

    def self.read(path = BASELINE_PATH)
      JSON.parse(File.read(path))
    end

    private

    def versions
      out = {}
      WeaponSkillVersion.includes(:skill, :weapon_skill).find_each do |v|
        key = [v.weapon_skill.weapon_granblue_id, v.weapon_skill.position, v.ordinal, v.skill&.name_en].join("|")
        out[key] = {
          "gate" => [v.unlock_level, v.min_uncap, v.transcendence_stage],
          "frame" => [v.resolved_modifier, v.resolved_series, v.resolved_size, v.multiplier_frame],
          "data" => sorted(v.weapon_skill_data.map { |d| row(d, self.class.data_columns) }),
          "effects" => sorted(v.weapon_skill_effects.map { |e| row(e, self.class.effect_columns) })
        }
      end
      out.sort.to_h
    end

    def keys
      WeaponSkillEffect.where.not(key_slug: nil).group_by(&:key_slug).sort.to_h do |slug, effects|
        [slug, sorted(effects.map { |e| row(e, self.class.effect_columns) })]
      end
    end

    def row(record, columns)
      columns.map do |c|
        value = record.public_send(c)
        value.is_a?(BigDecimal) ? value.to_f : value
      end
    end

    def sorted(rows) = rows.sort_by { |r| JSON.generate(r) }
  end
end
