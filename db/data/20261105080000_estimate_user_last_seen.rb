# frozen_string_literal: true

# last_seen_at only starts recording once it ships, so give everyone a first
# value from what we already know: the latest time each user was certainly
# active. Each signal is a moment the user did something:
#
# - signing in or refreshing their session (oauth_access_tokens.created_at)
# - using the extension (users.last_extension_version_at)
# - changing their settings (users.updated_at)
# - creating a team (parties.created_at; updated_at isn't used, since data
#   migrations have touched teams in bulk)
# - changing their collection (collection_*.updated_at)
# - favoriting a team (favorites.created_at)
#
# The result is a lower bound: they may have visited since without leaving a
# trace. Only users with no last_seen_at yet are filled in, so real stamps
# are never overwritten, and running this again changes nothing.
class EstimateUserLastSeen < ActiveRecord::Migration[8.1]
  def up
    filled = execute(<<~SQL.squish).cmd_tuples
      UPDATE users SET last_seen_at = estimate.seen_at
      FROM (
        SELECT users.id,
               LEAST(GREATEST(
                 (SELECT MAX(created_at) FROM oauth_access_tokens WHERE resource_owner_id = users.id),
                 users.last_extension_version_at,
                 users.updated_at,
                 (SELECT MAX(created_at) FROM parties WHERE user_id = users.id),
                 (SELECT MAX(updated_at) FROM collection_characters WHERE user_id = users.id),
                 (SELECT MAX(updated_at) FROM collection_weapons WHERE user_id = users.id),
                 (SELECT MAX(updated_at) FROM collection_summons WHERE user_id = users.id),
                 (SELECT MAX(created_at) FROM favorites WHERE user_id = users.id)
               ), NOW()) AS seen_at
        FROM users
        WHERE users.last_seen_at IS NULL
      ) AS estimate
      WHERE users.id = estimate.id AND estimate.seen_at IS NOT NULL
    SQL

    say "Estimated last_seen_at for #{filled} users"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
