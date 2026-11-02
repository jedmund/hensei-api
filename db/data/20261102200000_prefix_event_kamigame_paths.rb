# frozen_string_literal: true

# Event Kamigame paths were stored relative to /グラブル/イベント/; they're now
# relative to /グラブル/, since some events (Exo Crucible, under 神滅戦/) live in
# other folders. Existing paths get the イベント/ folder they assumed.
class PrefixEventKamigamePaths < ActiveRecord::Migration[8.1]
  PREFIX = 'イベント/'

  def up
    Event.where.not(kamigame: [nil, ''])
         .where.not('kamigame LIKE ?', "#{PREFIX}%")
         .update_all(['kamigame = ? || kamigame', PREFIX])
  end

  def down
    Event.where('kamigame LIKE ?', "#{PREFIX}%")
         .update_all(['kamigame = substr(kamigame, ?)', PREFIX.length + 1])
  end
end
