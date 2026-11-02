# frozen_string_literal: true

# Raids get an optional short name for places that already show their group
# (Home's raid tabs, the raid picker): "Lv200" under "Exo Diablo Crucible".
# Events get a Japanese banner next to the English one, whose art has
# English text baked in.
class AddShortNamesAndJapaneseBanners < ActiveRecord::Migration[8.1]
  def change
    add_column :raids, :short_name_en, :string
    add_column :raids, :short_name_jp, :string
    add_column :events, :image_key_jp, :string
  end
end
