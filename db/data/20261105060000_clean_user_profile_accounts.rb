# frozen_string_literal: true

# The settings form took any number as a Granblue ID (27 accounts had 0) and
# any text as a YouTube handle or wiki username (some pasted their channel's
# or user page's URL, which made links like youtube.com/@https://…). User now
# validates all three; this clears the IDs that can't be real and rewrites
# YouTube and wiki values into their stored forms (YoutubeChannel,
# WikiProfile), clearing any it can't read.
class CleanUserProfileAccounts < ActiveRecord::Migration[8.1]
  def up
    cleared_ids = User.where(granblue_id: ...100).update_all(granblue_id: nil)

    say "Granblue IDs cleared: #{cleared_ids}"
    clean(:youtube, YoutubeChannel)
    clean(:wiki_profile, WikiProfile)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # Rewrites each value into the stored form, clearing any that won't fit it
  def clean(column, form)
    rewritten = cleared = 0
    User.where.not(column => nil).find_each do |user|
      value = user[column]
      normalized = form.normalize(value)
      normalized = nil unless normalized.nil? || normalized.match?(form::FORMAT)
      next if normalized == value

      normalized.nil? ? cleared += 1 : rewritten += 1
      user.update_column(column, normalized) # rubocop:disable Rails/SkipsModelValidations
    end
    say "#{column} rewritten: #{rewritten}, cleared: #{cleared}"
  end
end
