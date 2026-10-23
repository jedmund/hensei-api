# frozen_string_literal: true

module SummonAuras
  module Build
    # Runs the summon-aura build over a set of summons. Every entry point goes through here:
    # the deploy hook (.deploy), the on-save job (SummonAuras::BuildJob), the editor's Reparse
    # (Granblue::EntityReparser) and rake granblue:build_summon_auras.
    #
    #   write:  each stale summon is built and written (Writer) in its own savepoint and its
    #           fingerprint stored. One that raises keeps its rows, is counted and logged, and
    #           stays stale.
    #   shadow: the same, inside one transaction that's rolled back; prints a summary and the
    #           differences.
    #
    # Scope: summons with a stored wiki_raw or existing auras; ids: (granblue_ids) narrows it.
    # Stale: the Fingerprint differs from the stored one; all: true builds every summon in scope.
    #
    # Never deletes from a missing source: a summon with existing auras and no wiki_raw is
    # reported as no_source, and one whose build comes out empty (a page with no aura fields,
    # such as a character page stored for a summon) as empty; neither is written nor
    # fingerprinted. A summon with no auras whose build is empty is fingerprinted, so it isn't
    # rebuilt every deploy.
    class Runner
      MODES = %w[shadow write].freeze
      LOAD_BATCH = 100

      # status: built | failed | no_source | empty
      Result = Struct.new(:summon, :status, :report, :error, keyword_init: true) do
        def changed? = report&.changed? || false
      end

      Summary = Struct.new(:mode, :in_scope, :stale, :built, :failed, :errors, :no_source, :empty, :counts,
                           :results, :seconds, keyword_init: true) do
        def differing = results.count(&:changed?)
        def drift? = differing.positive? || failed.positive? || empty.positive?
      end

      # The deploy hook (db:migrate:with_data), in SUMMON_AURA_BUILD's mode.
      #   off:    nothing.
      #   shadow: summary plus the first 50 differences; never raises, so it can't fail a deploy.
      #   write:  builds the stale summons; one that fails keeps its rows and is retried by the
      #           next deploy, and the deploy carries on.
      def self.deploy(mode: SummonAuras.build_mode, io: $stdout)
        case mode
        when "shadow"
          begin
            new(mode: "shadow", diff_limit: 50, io: io).call
          rescue StandardError => e
            io.puts "build_summon_auras (shadow) failed; the deploy continues: #{e.class}: #{e.message}"
            nil
          end
        when "write"
          summary = new(mode: "write", io: io).call
          io.puts "build_summon_auras (write): #{summary.failed} summons failed and kept their existing rows" if summary.failed.positive?
          summary
        end
      end

      def initialize(mode:, ids: nil, all: false, diff_limit: nil, io: $stdout)
        raise ArgumentError, "mode must be one of #{MODES.join(', ')} (got #{mode.inspect})" unless MODES.include?(mode)

        @mode = mode
        @ids = ids.presence&.map(&:to_s)
        @all = all
        @diff_limit = diff_limit
        @io = io
      end

      def call
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Summon.reset_column_information # the fingerprint column may be from this deploy's migration
        @summary = Summary.new(mode: @mode, in_scope: 0, stale: 0, built: 0, failed: 0, errors: [], no_source: 0, empty: 0,
                               counts: Writer::Report.zero, results: [])

        if @mode == "write"
          run
        else
          ActiveRecord::Base.transaction do
            run
            raise ActiveRecord::Rollback
          end
        end

        @summary.seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        print_changes if @mode == "shadow"
        @io.puts summary_line
        @summary
      end

      # Summons in scope (ids: narrows), ordered by granblue_id.
      def scope
        relation = Summon.with_source(:wiki_raw).or(Summon.where(granblue_id: SummonAura.select(:summon_granblue_id)))
        relation = relation.where(granblue_id: @ids) if @ids
        relation.order(:granblue_id)
      end

      private

      def run
        each_target(targets) { |summon, fingerprint| build(summon, fingerprint) }
      end

      # → [[summon id, fingerprint]] for the stale summons, from the sources' stored sha256.
      def targets
        wiki = Source.select(1).where(owner_type: Summon.polymorphic_name, kind: "wiki_raw", key: "")
                     .where("sources.owner_id = summons.id")
        rows = scope.pluck(:id, :granblue_id, Arel.sql("NOT EXISTS (#{wiki.to_sql})"), :summon_aura_build_fingerprint)
        report_unknown_ids(rows.map(&:second))
        @summary.in_scope = rows.size
        blank, sourced = rows.partition { |row| row[2] }
        Summon.where(id: blank.map(&:first)).order(:granblue_id).each { |summon| no_source(summon) }
        current = Fingerprint.new.for_relation(Summon.where(id: sourced.map(&:first)))
        candidates = sourced.filter_map do |id, _, _, stored|
          [id, current.fetch(id)] if @all || stored != current.fetch(id)
        end
        @summary.stale = candidates.size
        candidates
      end

      # Loads the targets a batch at a time, with their sources and series.
      def each_target(targets)
        fingerprint_by_id = targets.to_h
        fingerprint_by_id.keys.each_slice(LOAD_BATCH) do |batch|
          Summon.where(id: batch).preload(:sources, :summon_series).order(:granblue_id).each do |summon|
            yield summon, fingerprint_by_id.fetch(summon.id)
          end
        end
      end

      def build(summon, fingerprint)
        records = Build.for(summon)
        return empty(summon) if records.empty? && SummonAura.exists?(summon_granblue_id: summon.granblue_id)

        report = nil
        # A savepoint per summon: a failed write rolls back that summon alone and leaves the
        # surrounding (shadow) transaction usable.
        ActiveRecord::Base.transaction(requires_new: true) do
          report = Writer.call(summon.granblue_id, records)
          summon.update_columns(summon_aura_build_fingerprint: fingerprint) if @mode == "write"
        end
        @summary.counts.merge!(report)
        @summary.built += 1
        @summary.results << Result.new(summon: summon, status: "built", report: report)
      rescue StandardError => e
        @summary.failed += 1
        @summary.errors << [summon.granblue_id, e]
        @summary.results << Result.new(summon: summon, status: "failed", error: e)
        @io.puts "#{label(summon)}: #{e.class}: #{e.message.lines.first&.strip}"
      end

      def no_source(summon)
        @summary.no_source += 1
        @summary.results << Result.new(summon: summon, status: "no_source")
        @io.puts "#{label(summon)}: no wiki_raw; kept its existing auras"
      end

      def empty(summon)
        @summary.empty += 1
        @summary.results << Result.new(summon: summon, status: "empty")
        @io.puts "#{label(summon)}: the build made no auras; kept its existing auras"
      end

      def print_changes
        lines = @summary.results.select(&:changed?).flat_map do |result|
          result.report.changes.map do |kind, (slot, uncap, stage), diff|
            columns = diff.map { |column, (before, after)| "#{column}: #{before.inspect} → #{after.inspect}" }
            "  #{kind} #{label(result.summon)} #{slot} #{uncap}★ t#{stage}: #{columns.join('; ')}"
          end
        end
        return if lines.empty?

        shown = @diff_limit ? lines.first(@diff_limit) : lines
        @io.puts(*shown)
        @io.puts "  … #{lines.size - shown.size} more" if shown.size < lines.size
      end

      def report_unknown_ids(found)
        return unless @ids

        unknown = @ids - found
        @io.puts "Not in scope (no wiki_raw or auras): #{unknown.join(', ')}" if unknown.any?
      end

      def label(summon)
        "#{summon.granblue_id} #{summon.name_en}"
      end

      def summary_line
        c = @summary.counts
        "build_summon_auras (#{@mode}): #{@summary.in_scope} in scope, #{@summary.stale} " \
          "#{@all ? 'selected' : 'stale'}, #{@summary.built} built, #{@summary.failed} failed, " \
          "#{@summary.no_source} no source, #{@summary.empty} empty; #{@summary.differing} summons differ; " \
          "auras +#{c.created} ~#{c.updated} -#{c.deleted}; #{format('%.1f', @summary.seconds)}s"
      end
    end
  end
end
