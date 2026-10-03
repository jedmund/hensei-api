# frozen_string_literal: true

module Siero
  # SQL deliberately avoids application models so catalogue validation survives model changes.
  class RateupIdentity
    SOURCES = <<~SQL
      FROM RATEUP_SOURCE r
      LEFT JOIN gacha g ON g.id = r.gacha_id
      LEFT JOIN weapons lw ON g.drawable_type = 'Weapon' AND lw.id = g.drawable_id
      LEFT JOIN summons ls ON g.drawable_type = 'Summon' AND ls.id = g.drawable_id
      LEFT JOIN weapons nw ON r.drawable_type = 'Weapon' AND nw.id = r.drawable_id
      LEFT JOIN summons ns ON r.drawable_type = 'Summon' AND ns.id = r.drawable_id
    SQL

    def initialize(connection = ActiveRecord::Base.connection)
      @connection = connection
    end

    def report
      counts = @connection.select_one(<<~SQL).merge(duplicate_report)
        SELECT COUNT(*) AS rows,
          COUNT(*) FILTER (WHERE r.drawable_type IS NULL AND r.drawable_id IS NULL) AS legacy_only,
          COUNT(*) FILTER (WHERE r.gacha_id IS NULL AND r.drawable_id IS NOT NULL) AS new_only,
          COUNT(*) FILTER (WHERE r.gacha_id IS NOT NULL AND g.id IS NULL) AS orphaned_gacha,
          COUNT(*) FILTER (WHERE g.id IS NOT NULL AND
            (g.drawable_type IS NULL OR g.drawable_type NOT IN ('Weapon', 'Summon'))) AS invalid_legacy_type,
          COUNT(*) FILTER (WHERE g.drawable_type IN ('Weapon', 'Summon') AND lw.id IS NULL AND ls.id IS NULL) AS missing_legacy_item,
          COUNT(*) FILTER (WHERE r.drawable_type IS NOT NULL AND
            (r.drawable_type NOT IN ('Weapon', 'Summon') OR r.drawable_id IS NULL)) AS invalid_new_pair,
          COUNT(*) FILTER (WHERE r.drawable_type IS NULL AND r.drawable_id IS NOT NULL) AS partial_new_pair,
          COUNT(*) FILTER (WHERE r.drawable_type IN ('Weapon', 'Summon') AND nw.id IS NULL AND ns.id IS NULL) AS missing_new_item,
          COUNT(*) FILTER (WHERE r.drawable_id IS NOT NULL AND g.id IS NOT NULL AND
            (r.drawable_type IS DISTINCT FROM g.drawable_type OR r.drawable_id IS DISTINCT FROM g.drawable_id)) AS conflicting_identity,
          COUNT(*) FILTER (WHERE r.drawable_type IS NULL AND r.drawable_id IS NULL AND
            (lw.id IS NOT NULL OR ls.id IS NOT NULL)) AS backfillable
        #{SOURCES.sub('RATEUP_SOURCE', rateup_source)}
      SQL
      blockers = %w[legacy_only orphaned_gacha invalid_legacy_type missing_legacy_item invalid_new_pair
                    partial_new_pair missing_new_item conflicting_identity duplicate_groups]
      counts.merge('schema_ready' => schema_ready?,
                   'ready_for_cutover' => schema_ready? && blockers.all? { |key| counts.fetch(key).zero? })
    end

    def backfill
      raise 'Apply additive drawable schema before backfill' unless schema_ready?

      @connection.transaction do
        # Stabilize reconciliation and serialize concurrent reruns; old writers resume after commit.
        @connection.execute('LOCK TABLE gacha_rateups IN SHARE ROW EXCLUSIVE MODE')
        @connection.execute('LOCK TABLE gacha, weapons, summons IN SHARE MODE')
        before = preserved_values
        updated = @connection.update(<<~SQL)
          UPDATE gacha_rateups r SET drawable_type = g.drawable_type, drawable_id = g.drawable_id
          FROM gacha g
          WHERE r.gacha_id = g.id AND r.drawable_type IS NULL AND r.drawable_id IS NULL
            AND ((g.drawable_type = 'Weapon' AND EXISTS (SELECT 1 FROM weapons w WHERE w.id = g.drawable_id))
              OR (g.drawable_type = 'Summon' AND EXISTS (SELECT 1 FROM summons s WHERE s.id = g.drawable_id)))
        SQL
        raise 'Rate-up row count or preserved values changed' unless before == preserved_values

        report.merge('updated' => updated)
      end
    end

    private

    def schema_ready?
      @connection.column_exists?(:gacha_rateups, :drawable_type) && @connection.column_exists?(:gacha_rateups, :drawable_id)
    end

    def rateup_source
      return 'gacha_rateups' if schema_ready?

      '(SELECT gacha_rateups.*, NULL::text AS drawable_type, NULL::uuid AS drawable_id FROM gacha_rateups)'
    end

    def preserved_values
      @connection.select_rows('SELECT id, gacha_id, user_id, rate, created_at FROM gacha_rateups ORDER BY id')
    end

    def duplicate_report
      @connection.select_one(<<~SQL)
        SELECT COUNT(*) AS duplicate_groups, COALESCE(SUM(settings - 1), 0)::bigint AS duplicate_excess_rows
        FROM (
          SELECT COUNT(*) AS settings
          FROM #{rateup_source} r LEFT JOIN gacha g ON g.id = r.gacha_id
          WHERE COALESCE(r.drawable_id, g.drawable_id) IS NOT NULL
          GROUP BY r.user_id, COALESCE(r.drawable_type, g.drawable_type), COALESCE(r.drawable_id, g.drawable_id)
          HAVING COUNT(*) > 1
        ) duplicates
      SQL
    end
  end
end
