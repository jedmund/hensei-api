# frozen_string_literal: true

# Vitiation, Guile, Execration and Puncturing became parser modifiers, so the Odious
# weapons' skills now resolve to family rows by name (every element, including those
# released later). The parser isn't in the build fingerprint, so clearing it makes the
# deploy build, which runs after data migrations, reclassify those weapons.
class RebuildOdiousWeapons < ActiveRecord::Migration[8.1]
  def up
    Weapon.joins(:weapon_series).where(weapon_series: { slug: 'odious' })
          .where.not(weapon_skill_build_fingerprint: nil)
          .find_each { |weapon| weapon.update_column(:weapon_skill_build_fingerprint, nil) } # rubocop:disable Rails/SkipsModelValidations
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
