# frozen_string_literal: true

# The game calls this series "Draconic Weapons Provenance". Only the display name
# changes: the draconic-providence slug is referenced by code and stored rules.
class RenameDraconicProvenanceSeries < ActiveRecord::Migration[8.1]
  SLUG = 'draconic-providence'

  def up
    WeaponSeries.find_by(slug: SLUG)&.update!(name_en: 'Draconic Weapons Provenance')
  end

  def down
    WeaponSeries.find_by(slug: SLUG)&.update!(name_en: 'Draconic Weapons Providence')
  end
end
