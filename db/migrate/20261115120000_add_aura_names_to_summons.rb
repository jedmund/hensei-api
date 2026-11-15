# frozen_string_literal: true

# A summon's aura name in each language ("Zephyrus's Aura" / ゼピュロスの加護), written by the
# summon aura build (SummonAuras::Build.names). One name covers the main and sub aura.
class AddAuraNamesToSummons < ActiveRecord::Migration[8.1]
  def change
    add_column :summons, :aura_name_en, :string
    add_column :summons, :aura_name_jp, :string
  end
end
