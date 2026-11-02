# frozen_string_literal: true

# Event Kamigame paths were stored relative to /グラブル/イベント/; they're now
# relative to /グラブル/, since some events (Exo Crucible, under 神滅戦/) live in
# other folders. Existing paths get the イベント/ folder they assumed.
#
# Plain SQL rather than the Event model: later schema migrations add columns
# the model declares, and this runs before them on a fresh database.
class PrefixEventKamigamePaths < ActiveRecord::Migration[8.1]
  PREFIX = 'イベント/'

  def up
    execute <<~SQL.squish
      UPDATE events SET kamigame = #{quote(PREFIX)} || kamigame
      WHERE kamigame IS NOT NULL AND kamigame <> '' AND kamigame NOT LIKE #{quote("#{PREFIX}%")}
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE events SET kamigame = substr(kamigame, #{PREFIX.length + 1})
      WHERE kamigame LIKE #{quote("#{PREFIX}%")}
    SQL
  end

  private

  def quote(value)
    connection.quote(value)
  end
end
