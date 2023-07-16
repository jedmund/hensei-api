# frozen_string_literal: true

class MigrateAwakeningTypeToNewAwakeningType < ActiveRecord::Migration[7.0]
  def up
    GridWeapon.all.each do |weapon|
      if weapon.awakening_type&.positive? && weapon.awakening_type <= 3
        slug = if weapon.awakening_type == 1
                 'weapon-atk'
               elsif weapon.awakening_type == 2
                 'weapon-def'
               elsif weapon.awakening_type == 3
                 'weapon-special'
               end

        new_awakening = Awakening.find_by(slug: slug)
        weapon.awakening_id = new_awakening.id
        weapon.save!
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
