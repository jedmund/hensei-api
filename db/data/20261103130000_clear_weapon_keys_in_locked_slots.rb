# frozen_string_literal: true

# Clears keys saved in slots their copy's uncap hasn't opened (a Pendulum on a 3★
# Opus, Tria on a 4★ Ultima): the game can't have them, and WeaponKeySlots now
# rejects setting them. Grid and collection weapons alike. Irreversible: the
# removed keys were impossible states.
class ClearWeaponKeysInLockedSlots < ActiveRecord::Migration[8.0]
  COLUMNS = WeaponKeySlots::KEY_COLUMNS.map { |column| "#{column}_id" }.freeze

  def up
    [GridWeapon, CollectionWeapon].each { |model| clear_locked_keys(model) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def clear_locked_keys(model)
    keys = WeaponKey.all.index_by(&:id)
    series = WeaponSeries.where(slug: WeaponKeySlots::MIN_UNCAP.keys).ids
    scope = model.joins(:weapon).where(weapons: { weapon_series_id: series })
                 .where(COLUMNS.map { |column| "#{model.table_name}.#{column} IS NOT NULL" }.join(' OR '))

    scope.includes(weapon: :weapon_series).find_each do |record|
      locked = COLUMNS.select do |column|
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
