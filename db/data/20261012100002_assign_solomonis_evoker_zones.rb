# frozen_string_literal: true

# Makes the five Allotropic Microcosm Evokers route-eligible by giving them
# the zone. Matched by granblue_id only (never by name), so alternate versions
# with the same names stay ineligible; style-swap rows sharing an id are
# skipped. A missing Evoker is logged and skipped. A zone set by hand is kept.
class AssignSolomonisEvokerZones < ActiveRecord::Migration[8.0]
  ZONE_SLUG = 'allotropic-microcosm'
  # granblue_id => [name for logs, Hensei element (D4)]
  EVOKERS = {
    '3040160000' => ['Maria Theresa', 3],
    '3040164000' => ['Caim', 4],
    '3040169000' => ['Nier', 5],
    '3040163000' => ['Estarriola', 1],
    '3040161000' => ['Fraux', 2]
  }.freeze

  def up
    Character.reset_column_information
    zone = Raid.find_by!(slug: ZONE_SLUG)

    EVOKERS.each do |granblue_id, (name, element)|
      rows = Character.where(granblue_id: granblue_id, style_swap: false).to_a
      if rows.size != 1
        say "Skipping #{name} (#{granblue_id}): expected one character, found #{rows.size}"
        next
      end

      character = rows.first
      say "Note: #{name} (#{granblue_id}) has element #{character.element}, expected #{element}" if character.element != element
      next if character.solomonis_zone_id.present?

      character.update_columns(solomonis_zone_id: zone.id)
    end
  end

  def down
    Character.where(granblue_id: EVOKERS.keys).update_all(solomonis_zone_id: nil)
  end
end
