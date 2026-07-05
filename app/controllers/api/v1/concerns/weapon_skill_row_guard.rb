# frozen_string_literal: true

module Api
  module V1
    module Concerns
      # Shared blast-radius guard for deleting calculator input rows
      # (weapon_skill_data / weapon_skill_effects). Without force=true the
      # delete returns 409 with the affected versions/weapons so the UI can
      # confirm with real numbers.
      module WeaponSkillRowGuard
        private

        def guarded_destroy(row)
          impact = blast_radius(row)
          if params[:force] != 'true' && impact[:affected_versions].positive?
            return render json: { error: 'confirmation_required', **impact }, status: :conflict
          end

          row.destroy!
          render json: { deleted: true, **impact }
        end

        def blast_radius(row)
          versions = WeaponSkillVersion.includes(weapon_skill: :weapon)
          versions = if row.weapon_skill_version_id.present?
                       versions.where(id: row.weapon_skill_version_id)
                     else
                       versions.where(skill_modifier: row.modifier)
                     end
          weapons = versions.filter_map { |v| v.weapon_skill&.weapon }.uniq
          {
            affected_versions: versions.size,
            affected_weapons: weapons.size,
            sample_weapons: weapons.first(8).map(&:name_en)
          }
        end
      end
    end
  end
end
