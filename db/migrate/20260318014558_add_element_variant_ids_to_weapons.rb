class AddElementVariantIdsToWeapons < ActiveRecord::Migration[8.0]
  def change
    add_column :weapons, :element_variant_ids, :jsonb
  end
end
