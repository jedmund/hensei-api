# frozen_string_literal: true

# Fills raids.released_at from data/raid_release_dates.json: the first "New
# Raid" entry for each battle on gbf.wiki's What's New pages (2017 onwards),
# reviewed by hand. Raids older than those pages, event stages and showdowns
# have no entry and stay empty. Only empty dates are filled, so editors' dates
# win. Logs counts only.
class BackfillRaidReleaseDates < ActiveRecord::Migration[8.1]
  def up
    dates = JSON.parse(Rails.root.join('data/raid_release_dates.json').read)
    filled = dates.sum do |slug, entry|
      Raid.where(slug: slug, released_at: nil).update_all(released_at: entry.fetch('released_at'))
    end
    say "#{filled} of #{dates.size} raid release dates filled"
  end

  def down
    # Nothing to undo: the dates stay useful, and editors may have changed them.
  end
end
