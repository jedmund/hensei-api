# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillVersionsController < Api::V1::ApiController
      before_action :ensure_editor_role

      # Classification is edited through the override columns, never the derived
      # skill_modifier/skill_series/skill_size: a reparse rewrites those, so an
      # edit there would be silently lost. Overrides are curation and survive it.
      OVERRIDE_FIELDS = %w[modifier_override series_override size_override suppressed_boosts].freeze

      # PATCH /weapon_skill_versions/:id — classification only; labels live on
      # the shared Skill row (skills#update).
      def update
        version = WeaponSkillVersion.find(params[:id])
        version.assign_attributes(version_params)
        return render_validation_error_response(version) unless valid_overrides?(version)

        version.overrides_edited_at = Time.current if version.changed.intersect?(OVERRIDE_FIELDS)
        version.save!
        render json: WeaponSkillVersionBlueprint.render_as_hash(version).merge(id: version.id,
                                                                               skill_id: version.skill_id)
      end

      private

      def version_params
        permitted = params.require(:weapon_skill_version)
                          .permit(:modifier_override, :series_override, :size_override,
                                  :main_hand_only, :mc_only, :scales_with_skill_level, :multiplier_frame,
                                  :min_uncap, :transcendence_stage, :skill_id, suppressed_boosts: [])
        # Blank selects clear an override (back to the derived value).
        %w[modifier_override series_override size_override].each do |field|
          permitted[field] = permitted[field].presence if permitted.key?(field)
        end
        permitted
      end

      # The override columns are free-form strings; keep them to the values the
      # derived columns accept ("none" pins "no family" on the modifier).
      def valid_overrides?(version)
        allowed = {
          modifier_override: WeaponSkillVersion::VALID_MODIFIERS + ['none'],
          series_override: WeaponSkillVersion.skill_series.keys,
          size_override: WeaponSkillVersion.skill_sizes.keys
        }
        allowed.each do |field, values|
          next unless version.attribute_changed?(field)

          value = version[field]
          version.errors.add(field, :inclusion, value: value) if value && !values.include?(value)
        end
        version.errors.empty?
      end
    end
  end
end
