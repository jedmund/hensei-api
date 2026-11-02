# frozen_string_literal: true

# Registers the Impulse family (Template:Weapon Skills/Impulse, new with Ragnarok's Graphite
# Impulse): unboostable, granting DMG Supp. and DMG Cap (Sp.). The calculator reads the family's
# aura_boostable; its effects are canonical curation (_canonical.json). Creates the row only if
# it's missing, so a later template import or an editor's change stays.
class AddImpulseWeaponSkillFamily < ActiveRecord::Migration[8.1]
  def up
    created = connection.select_value(<<~SQL.squish)
      INSERT INTO weapon_skill_families (name, aura_boostable, boosts, icon_stems, created_at, updated_at)
      VALUES ('Impulse', false, '["DMG Supp.", "DMG Cap (Sp.)"]'::jsonb, '{}'::jsonb, now(), now())
      ON CONFLICT (name) DO NOTHING
      RETURNING name
    SQL
    say created ? 'Impulse family added' : 'Impulse family already present'
  end

  def down
    # Kept: other rows may refer to the family by name.
  end
end
