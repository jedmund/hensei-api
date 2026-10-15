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

    DATA_COLUMNS = %i[boost_type formula_type sl1 sl10 sl15 sl20 sl25 coefficient aura_boostable].freeze
    EFFECT_COLUMNS = %i[boost_type scaling_kind value per_copy_cap total_cap cap_formula condition
                        series aura_boostable].freeze

    def self.capture(meta: {})
      new.capture(meta: meta)
    end

    def capture(meta: {})
      { "meta" => meta.merge("captured_at" => Time.current.utc.iso8601),
        "versions" => versions, "keys" => keys }
    end

    # → { changed: [{key, fields: {field => [before, after]}}], missing: [keys], added: [keys], keys: … }
    def self.diff(before, after)
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

    def self.write(snapshot, path = BASELINE_PATH)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "#{JSON.pretty_generate(snapshot)}\n")
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
          "data" => sorted(v.weapon_skill_data.map { |d| row(d, DATA_COLUMNS) }),
          "effects" => sorted(v.weapon_skill_effects.map { |e| row(e, EFFECT_COLUMNS) })
        }
      end
      out.sort.to_h
    end

    def keys
      WeaponSkillEffect.where.not(key_slug: nil).group_by(&:key_slug).sort.to_h do |slug, effects|
        [slug, sorted(effects.map { |e| row(e, EFFECT_COLUMNS) })]
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
