# frozen_string_literal: true

# Adds the Evoking Solomonis raid group (section 3, after the Sandbox groups)
# and its live zone, Allotropic Microcosm. Paracyclic Microcosm waits until it
# opens. Names come from db/seed/solomonis/names.json when present.
#
# raid_groups.name_jp is NOT NULL and there is no Japanese name yet, so it
# holds the English name until names.json supplies one; a rerun replaces it
# then. Existing values are never cleared.
class CreateEvokingSolomonisZone < ActiveRecord::Migration[8.0]
  NAMES_PATH = Rails.root.join('db/seed/solomonis/names.json')
  GROUP_NAME_EN = 'Evoking Solomonis'
  SECTION = 3
  ZONES = [{ 'slug' => 'allotropic-microcosm', 'name_en' => 'Allotropic Microcosm', 'name_jp' => nil }].freeze

  def up
    RaidGroup.reset_column_information
    Raid.reset_column_information

    transaction do
      group = upsert_group
      zones.each { |zone| upsert_zone(group, zone) }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Parties and Evokers may point at the zone; remove it by hand.'
  end

  private

  def names
    @names ||= File.exist?(NAMES_PATH) ? JSON.parse(File.read(NAMES_PATH)) : {}
  end

  def upsert_group
    seed = names['raid_group'] || {}
    group = RaidGroup.find_by(content_mode: RaidGroup::SOLOMONIS) || new_group
    group.name_en ||= seed['name_en'].presence || GROUP_NAME_EN
    name_jp = seed['name_jp'].presence
    group.name_jp = name_jp if name_jp && (group.name_jp.blank? || group.name_jp == group.name_en)
    group.name_jp = group.name_en if group.name_jp.blank?
    group.save!
    group
  end

  def new_group
    order = RaidGroup.where(section: SECTION).maximum(:order).to_i + 1
    RaidGroup.new(content_mode: RaidGroup::SOLOMONIS, section: SECTION, order: order, difficulty: 0,
                  extra: false, hl: true, guidebooks: false, unlimited: false)
  end

  def zones
    seeded = names['zones']&.select { |zone| zone['create_now'] }
    seeded.presence || ZONES
  end

  def upsert_zone(group, zone)
    raid = Raid.find_or_initialize_by(slug: zone['slug'])
    if raid.new_record?
      raid.assign_attributes(group: group, element: 0, player_count: 1, level: nil)
    elsif raid.group_id != group.id
      raise "Raid #{zone['slug']} exists outside the Evoking Solomonis group"
    end
    raid.name_en ||= zone['name_en']
    raid.name_jp ||= zone['name_jp'].presence
    raid.save!
  end
end
