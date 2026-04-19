class BackfillMembershipJoinedAtFromClaimedPhantoms < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE crew_memberships cm
      SET joined_at = sub.earliest_joined_at
      FROM (
        SELECT
          pp.claimed_by_id AS user_id,
          pp.crew_id       AS crew_id,
          MIN(pp.joined_at) AS earliest_joined_at
        FROM phantom_players pp
        WHERE pp.claim_confirmed = TRUE
          AND pp.claimed_by_id IS NOT NULL
          AND pp.joined_at IS NOT NULL
        GROUP BY pp.claimed_by_id, pp.crew_id
      ) sub
      WHERE cm.user_id = sub.user_id
        AND cm.crew_id = sub.crew_id
        AND cm.retired = FALSE
        AND (cm.joined_at IS NULL OR sub.earliest_joined_at < cm.joined_at);
    SQL
  end

  def down
    # Not reversible — original joined_at values aren't retained.
  end
end
