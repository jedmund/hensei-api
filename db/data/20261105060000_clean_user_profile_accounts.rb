# frozen_string_literal: true

# The settings form took any number as a Granblue ID (27 accounts had 0) and
# any text as a YouTube handle (some pasted their channel's URL, which made
# links like youtube.com/@https://…). User now validates both; this clears
# the IDs that can't be real and rewrites YouTube values into the stored form
# (YoutubeChannel), clearing any it can't read.
class CleanUserProfileAccounts < ActiveRecord::Migration[8.1]
  def up
    cleared_ids = User.where(granblue_id: ...100).update_all(granblue_id: nil)

    rewritten = cleared = 0
    User.where.not(youtube: nil).find_each do |user|
      normalized = YoutubeChannel.normalize(user.youtube)
      normalized = nil unless normalized.nil? || normalized.match?(YoutubeChannel::FORMAT)
      next if normalized == user.youtube

      normalized.nil? ? cleared += 1 : rewritten += 1
      user.update_column(:youtube, normalized) # rubocop:disable Rails/SkipsModelValidations
    end

    say "Granblue IDs cleared: #{cleared_ids}; YouTube rewritten: #{rewritten}, cleared: #{cleared}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
