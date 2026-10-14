# frozen_string_literal: true

# Makes the ten Evokers route-eligible by giving each its zone: five in
# Allotropic Microcosm, five in Paracyclic Microcosm. Matched by granblue_id
# only (never by name), so alternate versions with the same names stay
# ineligible; style-swap rows sharing an id are skipped. A missing Evoker is
# logged and skipped. A zone set by hand is kept.
class AssignSolomonisEvokerZones < ActiveRecord::Migration[8.0]
  ALLOTROPIC = 'allotropic-microcosm'
  PARACYCLIC = 'paracyclic-microcosm'
  # granblue_id => [name for logs, Hensei element (D4), zone slug]
  EVOKERS = {
    '3040160000' => ['Maria Theresa', 3, ALLOTROPIC],
    '3040164000' => ['Caim', 4, ALLOTROPIC],
    '3040169000' => ['Nier', 5, ALLOTROPIC],
    '3040163000' => ['Estarriola', 1, ALLOTROPIC],
    '3040161000' => ['Fraux', 2, ALLOTROPIC],
    '3040162000' => ['Geisenborger', 6, PARACYCLIC],
    '3040165000' => ['Lobelia', 4, PARACYCLIC],
    '3040166000' => ['Katzelia', 1, PARACYCLIC],
    '3040167000' => ['Alanaan', 2, PARACYCLIC],
    '3040168000' => ['Haaselia', 3, PARACYCLIC]
  }.freeze

  def up
    Character.reset_column_information
    zones = Raid.where(slug: [ALLOTROPIC, PARACYCLIC]).index_by(&:slug)

    EVOKERS.each do |granblue_id, (name, element, zone_slug)|
      zone = zones.fetch(zone_slug) { raise "Zone #{zone_slug} is missing; run CreateEvokingSolomonisZone first" }
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
