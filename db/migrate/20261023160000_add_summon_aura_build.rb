# frozen_string_literal: true

# The summon-aura build stores the digest of each summon's inputs here after a write
# (SummonAuras::Build::Fingerprint); a summon whose inputs still match isn't rebuilt. Its
# writer upserts by natural key, so the tier index becomes unique (prod has no duplicates).
class AddSummonAuraBuild < ActiveRecord::Migration[8.1]
  def change
    add_column :summons, :summon_aura_build_fingerprint, :string

    remove_index :summon_auras, %i[summon_granblue_id slot uncap_level transcendence_stage],
                 name: "index_summon_auras_on_summon_tier"
    add_index :summon_auras, %i[summon_granblue_id slot uncap_level transcendence_stage],
              unique: true, name: "index_summon_auras_on_summon_tier"
  end
end
