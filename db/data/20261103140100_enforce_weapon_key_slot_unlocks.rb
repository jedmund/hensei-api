# frozen_string_literal: true

# Seeds the key slot rules editors now keep in the Database, then clears saved keys
# the rules lock (GBF-209). From the gbf.wiki series pages (3★ = lvl 100, 4★ = 150,
# 5★ = 200):
#
# - Dark Opus: Pendulums in skill 2 at lvl 120 (4★); skill 3 (Pendulums/Chains) at 200.
# - Draconic: Four Orbs' Judgment at lvl 150 (4★); Six Dragons' Radiance at 200. It
#   has both slots, not one: saved Six Dragons' Telumas were already in slot 2.
# - Draconic Provenance: forged from a lvl-200 Draconic, both skills at 200.
# - Destroyer: Anklets modify skill 3, at lvl 150 (4★).
# - Ultima: Gate of Omnipotence at lvl 200. Atma weapons (the Ultima series' first
#   stage) have only the Gauph slot, so they get an "Atma" variant with one slot.
#
# The key clearing is irreversible: the removed keys were impossible in game.
class EnforceWeaponKeySlotUnlocks < ActiveRecord::Migration[8.0]
  MIN_UNCAPS = {
    'dark-opus' => [4, 5],
    'draconic' => [4, 5],
    'draconic-providence' => [5, 5],
    'destroyer' => [4],
    'ultima' => [0, 0, 5]
  }.freeze
  KEY_COLUMNS = %w[weapon_key1_id weapon_key2_id weapon_key3_id weapon_key4_id].freeze

  def up
    WeaponSeries.reset_column_information
    # Before any clearing: with one slot, Draconic's slot-2 Telumas would go too
    WeaponSeries.find_by(slug: 'draconic')&.update!(num_weapon_keys: 2)
    MIN_UNCAPS.each do |slug, levels|
      WeaponSeries.find_by(slug: slug)&.update!(key_slot_min_uncaps: levels)
    end
    add_atma_variant
    [GridWeapon, CollectionWeapon].each { |model| clear_locked_keys(model) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def add_atma_variant
    ultima = WeaponSeries.find_by(slug: 'ultima')
    return unless ultima

    atma = WeaponSeriesVariant.find_or_create_by!(weapon_series: ultima, name: 'Atma') do |variant|
      variant.num_weapon_keys = 1
    end
    ultima.weapons.where('name_en LIKE ?', 'Atma %').update_all(weapon_series_variant_id: atma.id) # rubocop:disable Rails/SkipsModelValidations
  end

  def clear_locked_keys(model)
    keys = WeaponKey.all.index_by(&:id)
    scope = model.where(KEY_COLUMNS.map { |column| "#{model.table_name}.#{column} IS NOT NULL" }.join(' OR '))

    scope.includes(weapon: %i[weapon_series weapon_series_variant]).find_each do |record|
      locked = KEY_COLUMNS.select do |column|
        key = keys[record[column]]
        key && !model.key_slot_unlocked_for?(record.weapon, record.uncap_level, key.slot)
      end
      next if locked.empty?

      # Direct column writes: other legacy fields on these rows may not pass today's
      # validations, and this cleanup shouldn't depend on them.
      record.update_columns(locked.index_with { nil }) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
