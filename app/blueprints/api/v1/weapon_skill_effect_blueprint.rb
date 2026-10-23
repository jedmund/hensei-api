# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillEffectBlueprint < ApiBlueprint
      fields :modifier, :boost_type, :series, :scaling_kind, :value_unit,
             :per_copy_cap, :total_cap, :shared_cap_group, :cap_formula,
             :count_basis, :count_cap, :condition, :target_instance,
             :aura_boostable, :stacking, :applies_to, :notes,
             :key_slug, :frame_rule, :weapon_skill_version_id, :manually_edited_at

      field :value do |effect|
        effect.value&.to_f
      end

      # Where the row comes from, for grouping in the editor: a weapon key,
      # a specific version's description, or the canonical family data.
      field :source do |effect|
        if effect.key_slug.present?
          'key'
        elsif effect.weapon_skill_version_id.present?
          'version'
        else
          'canonical'
        end
      end
    end
  end
end
