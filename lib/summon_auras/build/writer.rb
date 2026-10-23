# frozen_string_literal: true

module SummonAuras
  module Build
    # Writes one summon's built aura records (Build.for) over its stored rows, by natural key
    # (Build::KEY, a unique index): new tiers are inserted, changed ones updated in place (ids
    # survive), and tiers the build no longer makes are deleted. Unchanged rows aren't touched.
    # The upsert is one statement against the unique index, so two builds of a summon at once
    # can't duplicate a tier.
    #
    # Callers decide whether to write at all: the Runner never hands over an empty build for a
    # summon that has rows.
    class Writer
      # changes: [[:created | :updated | :deleted, key (slot, uncap, stage), { column => [before, after] }]]
      Report = Struct.new(:created, :updated, :deleted, :changes, keyword_init: true) do
        def self.zero = new(created: 0, updated: 0, deleted: 0, changes: [])

        def merge!(other)
          self.created += other.created
          self.updated += other.updated
          self.deleted += other.deleted
          changes.concat(other.changes)
          self
        end

        def changed? = (created + updated + deleted).positive?
      end

      def self.call(granblue_id, records)
        new(granblue_id, records).call
      end

      def initialize(granblue_id, records)
        @granblue_id = granblue_id.to_s
        @records = records
      end

      def call
        existing = SummonAura.where(summon_granblue_id: @granblue_id).index_by { |aura| tier(aura) }
        built = @records.index_by { |record| tier(record) }
        report = Report.zero

        upserts = built.filter_map do |key, record|
          before = existing[key]
          if before.nil?
            report.created += 1
            report.changes << [:created, key, COLUMNS.to_h { |c| [c, [nil, normalize(record[c])]] }]
          else
            diff = COLUMNS.filter_map { |c| [c, [normalize(before[c]), normalize(record[c])]] unless same?(before[c], record[c]) }.to_h
            next if diff.empty?

            report.updated += 1
            report.changes << [:updated, key, diff]
          end
          record.slice(*KEY, *COLUMNS).merge("summon_granblue_id" => @granblue_id)
        end
        SummonAura.upsert_all(upserts, unique_by: KEY, returning: false) if upserts.any?

        removed = existing.except(*built.keys)
        removed.each do |key, aura|
          report.deleted += 1
          report.changes << [:deleted, key, COLUMNS.to_h { |c| [c, [normalize(aura[c]), nil]] }]
        end
        SummonAura.where(id: removed.values.map(&:id)).delete_all if removed.any?

        report
      end

      private

      def tier(row)
        [row["slot"].to_s, row["uncap_level"].to_i, row["transcendence_stage"].to_i]
      end

      # value is decimal in the table and a float from the extractor.
      def normalize(value)
        value.is_a?(Numeric) ? value.to_f : value
      end

      def same?(stored, built)
        normalize(stored) == normalize(built)
      end
    end
  end
end
