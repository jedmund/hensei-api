# frozen_string_literal: true

require 'csv'

module PartyDifficulty
  class Calibration
    ##
    # Summarises a calibration run as markdown, plus a per-party CSV. When a
    # baseline run is given, also reports how parties moved between tiers.
    class Report
      PERCENTILES = [10, 25, 50, 75, 90, 95, 99].freeze
      TOP_MOVERS = 25

      def initialize(ruleset:, results:, baseline: nil, label: 'candidate')
        @ruleset = ruleset
        @results = results
        @baseline = baseline
        @label = label
      end

      def write(dir)
        FileUtils.mkdir_p(dir)
        File.write(File.join(dir, 'report.md'), markdown)
        File.write(File.join(dir, 'parties.csv'), csv)
      end

      def markdown
        sections = [
          "# Difficulty calibration: #{@label}",
          "Scored #{@results.size} parties on #{Time.current.utc.iso8601}.",
          score_section,
          tier_section,
          component_section,
          rule_section
        ]
        sections << movement_section if @baseline
        "#{sections.join("\n\n")}\n"
      end

      def csv
        CSV.generate do |out|
          names = @ruleset.components.map { |c| c['name'] }
          out << (%w[shortcode name score tier] + names.map { |n| "#{n}_raw" } + (@baseline ? %w[baseline_score baseline_tier] : []))
          baseline_by_id = @baseline&.index_by(&:party_id) || {}
          @results.sort_by { |r| -r.score }.each do |r|
            raws = names.map { |n| component(r, n)&.dig(:raw_score) }
            row = [r.shortcode, r.name, r.score, r.tier] + raws
            if @baseline
              b = baseline_by_id[r.party_id]
              row += [b&.score, b&.tier]
            end
            out << row
          end
        end
      end

      private

      def score_section
        scores = @results.map(&:score).sort
        header = (PERCENTILES.map { |p| "p#{p}" } + %w[max]).join(' | ')
        values = (PERCENTILES.map { |p| fmt(percentile(scores, p)) } + [fmt(scores.last)]).join(' | ')

        buckets = (0..9).map do |i|
          lo = i * 10
          count = scores.count { |s| s >= lo && (i == 9 ? s <= 100 : s < lo + 10) }
          "| #{lo}–#{lo + 10} | #{count} | #{pct(count, scores.size)} |"
        end

        <<~MD.strip
          ## Scores

          | #{header} |
          |#{'---|' * (PERCENTILES.size + 1)}
          | #{values} |

          | Range | Parties | Share |
          |---|---|---|
          #{buckets.join("\n")}
        MD
      end

      def tier_section
        counts = @results.group_by(&:tier).transform_values(&:size)
        rows = @ruleset.tiers.sort_by { |t| t['min_score'].to_f }.map do |t|
          n = counts[t['name']] || 0
          "| #{t['name']} | #{fmt(t['min_score'])}–#{fmt(t['max_score'])} | #{n} | #{pct(n, @results.size)} |"
        end

        <<~MD.strip
          ## Tiers

          | Tier | Range | Parties | Share |
          |---|---|---|---|
          #{rows.join("\n")}
        MD
      end

      # contribution_sum is what the component scored before dividing by its
      # denominator; its spread is what target_max should be set against.
      def component_section
        rows = @ruleset.components.map do |c|
          name = c['name']
          entries = @results.filter_map { |r| component(r, name) }
          scored = entries.select { |e| e[:contribution_sum] }
          sums = scored.map { |e| e[:contribution_sum].to_f }.sort
          raws = scored.map { |e| e[:raw_score].to_f }.sort
          fired = scored.count { |e| e[:contribution_sum].to_f.positive? }
          denominator = scored.first&.dig(:max_weight)

          [
            name, fmt(c['weight']), c['target_max'] ? fmt(c['target_max']) : '—', fmt(denominator),
            pct(entries.count { |e| e[:present] }, @results.size), pct(fired, @results.size),
            fmt(percentile(sums, 50)), fmt(percentile(sums, 90)), fmt(percentile(sums, 99)), fmt(sums.last),
            fmt(percentile(raws, 50)), fmt(percentile(raws, 99))
          ].join(' | ').then { |line| "| #{line} |" }
        end

        <<~MD.strip
          ## Components

          Points are the component's summed rule contributions before dividing by the denominator (`target_max`, or the sum of every rule's maximum when unset).

          | Component | Weight | target_max | Denominator | Present | Fired | Points p50 | p90 | p99 | max | Raw p50 | Raw p99 |
          |---|---|---|---|---|---|---|---|---|---|---|---|
          #{rows.join("\n")}
        MD
      end

      def rule_section
        totals = Hash.new { |h, k| h[k] = { parties: 0, points: 0.0 } }
        @results.each do |r|
          per_rule = Hash.new(0.0)
          Array(r.breakdown[:components]).each do |comp|
            Array(comp[:fired]).each { |f| per_rule[f[:id].to_s.delete_suffix('-additional')] += f[:weight].to_f }
          end
          per_rule.each do |id, points|
            totals[id][:parties] += 1
            totals[id][:points] += points
          end
        end

        rules = @ruleset.rules.select { |r| r.fetch('active', true) }
        rows = rules.sort_by { |r| [r['component'], -r['weight'].to_f] }.map do |r|
          t = totals[@ruleset.rule_id(r)]
          avg = t[:parties].positive? ? t[:points] / t[:parties] : nil
          "| #{r['component']} | #{r['name']} | #{fmt(r['weight'])} | #{t[:parties]} | #{pct(t[:parties], @results.size)} | #{fmt(avg)} |"
        end

        <<~MD.strip
          ## Rules

          | Component | Rule | Weight | Parties fired | Share | Avg points when fired |
          |---|---|---|---|---|---|
          #{rows.join("\n")}
        MD
      end

      def movement_section
        baseline_by_id = @baseline.index_by(&:party_id)
        pairs = @results.filter_map { |r| (b = baseline_by_id[r.party_id]) && [b, r] }
        names = @ruleset.tiers.sort_by { |t| t['min_score'].to_f }.pluck('name')
        baseline_names = pairs.map { |b, _| b.tier }.uniq
        from_names = baseline_names.compact.sort_by { |n| names.index(n) || 99 } + (baseline_names.include?(nil) ? [nil] : [])

        matrix = from_names.map do |from|
          cells = names.map { |to| pairs.count { |b, r| b.tier == from && r.tier == to } }
          "| #{from || '—'} | #{cells.join(' | ')} |"
        end

        changed = pairs.count { |b, r| b.tier_slug != r.tier_slug }
        movers = pairs.sort_by { |b, r| -(r.score - b.score).abs }.first(TOP_MOVERS).map do |b, r|
          "| #{r.shortcode} | #{r.name.to_s.tr('|', '/')} | #{fmt(b.score)} (#{b.tier}) | #{fmt(r.score)} (#{r.tier}) |"
        end

        <<~MD.strip
          ## Movement against the baseline

          #{changed} of #{pairs.size} parties (#{pct(changed, pairs.size)}) changed tier (compared by slug, so renaming a tier is not a change). Rows are baseline tiers, columns are candidate tiers.

          | From \\ to | #{names.join(' | ')} |
          |---|#{'---|' * names.size}
          #{matrix.join("\n")}

          ### Largest score changes

          | Party | Name | Baseline | Candidate |
          |---|---|---|---|
          #{movers.join("\n")}
        MD
      end

      def component(result, name)
        Array(result.breakdown[:components]).find { |c| c[:name] == name }
      end

      def percentile(sorted, rank)
        return nil if sorted.empty?

        sorted[((rank / 100.0) * (sorted.size - 1)).round]
      end

      def pct(count, total)
        total.zero? ? '—' : "#{(100.0 * count / total).round(1)}%"
      end

      def fmt(value)
        value.nil? ? '—' : value.to_f.round(2).to_s
      end
    end
  end
end
