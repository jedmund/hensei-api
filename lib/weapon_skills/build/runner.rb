# frozen_string_literal: true

module WeaponSkills
  module Build
    # Runs the build over a set of weapons (granblue:build_weapon_skills and the deploy hook).
    #
    #   write:  each stale weapon is built and written (Writer), its fingerprint stored;
    #           then the curation overlay is synced once and the key effects re-extracted.
    #   shadow: the same writes, sync and keys inside one transaction that's rolled back;
    #           the parity snapshot before and after is diffed and printed by series.
    #
    # Stale: the weapon's Fingerprint differs from the stored one (all: true builds every
    # weapon in scope). Scope: weapons with a stored wiki_raw source or existing slots,
    # narrowed by ids (granblue_ids) and series (weapon series slugs). A weapon that raises
    # is counted and logged, and the run continues.
    class Runner
      MODES = %w[shadow write].freeze

      class Failed < StandardError; end

      # errors: [[granblue_id, exception]] for the weapons that failed (EntityReparser re-raises).
      Summary = Struct.new(:mode, :in_scope, :stale, :built, :failed, :errors, :warnings, :counts, :diff, :seconds,
                           keyword_init: true)

      # The deploy hook, run after the curation sync in db:migrate:with_data.
      #   off:    nothing.
      #   shadow: summary plus the first 50 differences; never raises, so it can't fail a deploy.
      #   write:  builds the stale weapons and raises if any failed.
      def self.deploy(mode: WeaponSkills.build_mode, io: $stdout)
        case mode
        when "shadow"
          begin
            new(mode: "shadow", diff_limit: 50, io: io).call
          rescue StandardError => e
            io.puts "build_weapon_skills (shadow) failed; the deploy continues: #{e.class}: #{e.message}"
            nil
          end
        when "write"
          # A weapon that fails keeps its existing rows (its savepoint rolled back) and stays
          # stale, so the next deploy retries it. Failing the deploy here would leave the
          # other weapons written but the release blocked.
          summary = new(mode: "write", io: io).call
          if summary.failed.positive?
            io.puts "build_weapon_skills (write): #{summary.failed} weapons failed and kept their existing rows"
          end
          summary
        end
      end

      def initialize(mode:, ids: nil, series: nil, all: false, diff_limit: nil, io: $stdout, context: nil) # rubocop:disable Metrics/ParameterLists
        raise ArgumentError, "mode must be one of #{MODES.join(', ')} (got #{mode.inspect})" unless MODES.include?(mode)

        @mode = mode
        @ids = ids.presence&.map(&:to_s)
        @series = series.presence
        @all = all
        @diff_limit = diff_limit
        @io = io
        @context = context
      end

      def call
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Weapon.reset_column_information # the fingerprint columns may be from this deploy's migration
        @context ||= Build.context
        @summary = Summary.new(mode: @mode, built: 0, failed: 0, errors: [], warnings: 0, counts: Writer::Report.zero)
        targets = stale_weapons

        Granblue::Parsers::Wiki.offline(store: @context.store) do
          @mode == "write" ? write(targets) : shadow(targets)
        end

        @summary.seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        @io.puts summary_line
        @summary
      end

      # Weapons in scope, ordered by granblue_id.
      def scope
        relation = Weapon.where(id: WeaponSource.where(kind: "wiki_raw").where.not(weapon_id: nil).select(:weapon_id))
                         .or(Weapon.where(granblue_id: WeaponSkill.select(:weapon_granblue_id)))
        relation = relation.where(granblue_id: @ids) if @ids
        relation = relation.where(weapon_series_id: WeaponSeries.where(slug: @series).select(:id)) if @series
        relation.order(:granblue_id)
      end

      private

      # → [[weapon, fingerprint]] for the weapons to build.
      def stale_weapons
        fingerprints = Fingerprint.new(@context).preload_sources!
        weapons = scope.to_a
        report_unknown_ids(weapons)
        @summary.in_scope = weapons.size
        targets = weapons.map { |w| [w, fingerprints.for(w)] }
        targets.reject! { |w, fp| w.weapon_skill_build_fingerprint == fp } unless @all
        @summary.stale = targets.size
        targets
      end

      def report_unknown_ids(weapons)
        return unless @ids

        unknown = @ids - weapons.map(&:granblue_id)
        @io.puts "Not in scope (no stored wiki_raw source or slots): #{unknown.join(', ')}" if unknown.any?
      end

      def write(targets)
        build_all(targets, store_fingerprints: true)
        finish if @summary.built.positive?
      end

      def shadow(targets)
        ActiveRecord::Base.transaction do
          before = ParitySnapshot.capture
          build_all(targets, store_fingerprints: false)
          finish
          @summary.diff = ParitySnapshot.diff(before, ParitySnapshot.capture)
          raise ActiveRecord::Rollback
        end
        ParitySnapshot.write(@summary.diff, ParitySnapshot::LAST_DIFF_PATH)
        print_diff
      end

      def build_all(targets, store_fingerprints:)
        targets.each do |weapon, fingerprint|
          result = Build.for(weapon, context: @context)
          # A savepoint per weapon: a failed write rolls back that weapon alone and leaves
          # the surrounding (shadow) transaction usable.
          ActiveRecord::Base.transaction(requires_new: true) do
            @summary.counts.merge!(Writer.call(result, context: @context))
            if store_fingerprints
              weapon.update_columns(weapon_skill_build_fingerprint: fingerprint, weapon_skill_built_at: Time.current)
            end
          end
          @summary.warnings += result.warnings.size
          @summary.built += 1
        rescue StandardError => e
          @summary.failed += 1
          @summary.errors << [weapon.granblue_id, e]
          @io.puts "#{weapon.granblue_id} #{weapon.name_en}: #{e.class}: #{e.message.lines.first&.strip}"
        end
      end

      # The overlay sync and the key effects, once, after every weapon is written.
      def finish
        Granblue::CurationSnapshot.sync(log: @io)
        stats, = Granblue::Extractors::KeySkillExtractor.run(store: @context.store)
        @io.puts "Key skill extraction: #{stats.sort_by { |k, _| k.to_s }.to_h.inspect}"
      end

      # ParityReport by series; with diff_limit, its summary line and the first N differences.
      def print_diff
        out = StringIO.new
        ParityReport.new(@summary.diff, group: "series", io: out).print
        lines = out.string.lines
        return @io.print(out.string) if @diff_limit.nil?

        @io.print lines.first
        shown = 0
        lines.drop(1).each do |line|
          break if shown >= @diff_limit

          @io.print line
          shown += 1 unless line.start_with?("==")
        end
        total = lines.drop(1).count { |line| !line.start_with?("==") }
        @io.puts "… #{total - shown} more differences not shown" if total > shown
      end

      def summary_line
        c = @summary.counts
        "build_weapon_skills (#{@mode}): #{@summary.in_scope} in scope, #{@summary.stale} " \
          "#{@all ? 'selected' : 'stale'}, #{@summary.built} built, #{@summary.failed} failed; " \
          "versions +#{c[:versions_created]} ~#{c[:versions_updated]} -#{c[:versions_deleted]} " \
          "kept #{c[:versions_kept]}; slots +#{c[:slots_created]} -#{c[:slots_deleted]}; " \
          "rows +#{c[:rows_created]} ~#{c[:rows_updated]} -#{c[:rows_deleted]} " \
          "kept curated #{c[:rows_kept_curated]}; #{@summary.warnings} warnings; #{format('%.1f', @summary.seconds)}s"
      end
    end
  end
end
