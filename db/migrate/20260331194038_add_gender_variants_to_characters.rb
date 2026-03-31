class AddGenderVariantsToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :gender_variants, :boolean, default: false, null: false
  end
end
