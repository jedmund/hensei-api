# frozen_string_literal: true

# Corrects the passive portions of Dark Opus pendulums and chains. Triggered
# charge-attack/end-of-turn effects remain outside the boost-panel calculator.
class FixPassiveDarkOpusKeyEffects < ActiveRecord::Migration[8.0]
  KEY_SLUGS = %w[
    chain-depravity chain-falsehood chain-forbiddance chain-glorification chain-restoration chain-temperament
    pendulum-alpha pendulum-beta pendulum-prosperity pendulum-strength
    pendulum-strife pendulum-zeal
  ].freeze

  SNAPSHOT_COLUMNS = %w[
    modifier boost_type series scaling_kind value value_unit per_copy_cap total_cap
    shared_cap_group cap_formula count_basis count_cap condition target_instance depends_on
    aura_boostable seraphic_affected stacking applies_to battle_interaction notes key_slug frame_rule
  ].freeze

  def up
    WeaponSkillEffect.reset_column_information
    rows = snapshot_rows.select { |row| KEY_SLUGS.include?(row["key_slug"]) }

    # Keep curation markers/provenance attached to the replacement for the same
    # key/modifier/boost whenever an affected row was manually maintained.
    metadata = WeaponSkillEffect.where(key_slug: KEY_SLUGS)
                                .group_by { |effect| [effect.key_slug, effect.modifier, effect.boost_type] }
                                .transform_values do |effects|
      effects.filter_map do |effect|
        next if effect.manually_edited_at.nil? && effect.provenance.nil?

        { manually_edited_at: effect.manually_edited_at, provenance: effect.provenance }
      end
    end

    WeaponSkillEffect.where(key_slug: KEY_SLUGS).delete_all
    rows.each do |row|
      attrs = row.slice(*SNAPSHOT_COLUMNS)
      marker = metadata[[row["key_slug"], row["modifier"], row["boost_type"]]]&.shift || {}
      WeaponSkillEffect.create!(attrs.merge(marker))
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the replaced Dark Opus key data predates the canonical snapshot"
  end

  private

  def snapshot_rows
    payload = JSON.parse(File.read(Rails.root.join("data", "weapon_skill_effects.json")))
    payload.is_a?(Hash) ? payload.fetch("effects") : payload
  end
end
