# frozen_string_literal: true

class FixTranscendedCollectionWeaponUncapLevels < ActiveRecord::Migration[8.0]
  def up
    CollectionWeapon.where(uncap_level: 5).where('transcendence_step > 0').update_all(uncap_level: 6)
  end

  def down
    CollectionWeapon.where(uncap_level: 6).where('transcendence_step > 0').update_all(uncap_level: 5)
  end
end
