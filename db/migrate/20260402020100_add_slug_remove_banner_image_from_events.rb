class AddSlugRemoveBannerImageFromEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :slug, :string, null: false
    add_index :events, :slug, unique: true
    remove_column :events, :banner_image, :string
  end
end
