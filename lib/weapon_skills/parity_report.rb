# frozen_string_literal: true

module WeaponSkills
  # Prints a ParitySnapshot diff for people: a summary line, then each difference,
  # optionally grouped by weapon series.
  class ParityReport
    def initialize(diff, group: nil, io: $stdout)
      @diff = diff
      @group = group
      @io = io
    end

    def print
      changed, missing, added, keys = @diff.values_at("changed", "missing", "added", "keys")
      weapons = (changed.map { |c| c["key"] } + missing + added).map { |k| k.split("|").first }.uniq
      if ParitySnapshot.empty_diff?(@diff)
        @io.puts "PARITY: no differences"
        return
      end

      @io.puts "PARITY: #{changed.size} changed, #{missing.size} missing, #{added.size} added versions " \
               "on #{weapons.size} weapons; #{keys.size} key differences"
      lines.group_by(&:first).sort_by { |g, _| g.to_s }.each do |group, rows|
        @io.puts "== #{group}" if @group
        rows.each { |pair| @io.puts pair.last }
      end
      keys.each { |k| @io.puts "  key #{k['key_slug']}: #{short(k['before'])} -> #{short(k['after'])}" }
    end

    private

    def lines
      series = series_by_weapon
      out = @diff["missing"].map { |k| [series[k.split("|").first], "  - #{k}"] }
      out += @diff["added"].map { |k| [series[k.split("|").first], "  + #{k}"] }
      out + @diff["changed"].flat_map do |c|
        c["fields"].map do |field, (before, after)|
          [series[c["key"].split("|").first], "  ~ #{c['key']} #{field}: #{short(before)} -> #{short(after)}"]
        end
      end
    end

    def series_by_weapon
      return Hash.new("all") unless @group == "series"

      Weapon.includes(:weapon_series).to_h { |w| [w.granblue_id, w.weapon_series&.slug || "(none)"] }
    end

    def short(value) = JSON.generate(value).truncate(160)
  end
end
