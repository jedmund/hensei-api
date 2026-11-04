# frozen_string_literal: true

module Api
  module V1
    # Weapon-skill FAMILIES: the modifier-keyed aggregate the calculator
    # resolves values through. A family is a virtual resource over the
    # canonical weapon_skill_data / weapon_skill_effects rows, the
    # weapon_skill_versions classified into it, and the weapon keys whose
    # effects reference it. A version's family is its resolved modifier
    # (override, else derived), the one the calculator reads.
    class WeaponSkillFamiliesController < Api::V1::ApiController
      # GET /weapon_skill_families
      def index
        render json: { weapon_skill_families: WeaponSkillFamilyIndex.new(**index_filters).call }
      end

      # GET /weapon_skill_families/:modifier
      def show
        modifier = params[:modifier]
        data = WeaponSkillDatum.where(modifier: modifier).order(:boost_type, :series, :size)
        effects = WeaponSkillEffect.where(modifier: modifier).order(:boost_type)
        versions = WeaponSkillVersion.includes(:skill, weapon_skill: :weapon)
                                     .in_family(modifier)
        version_effects = WeaponSkillEffect.where(weapon_skill_version_id: versions.map(&:id))
        all_effects = (effects + version_effects.reject { |e| e.modifier == modifier }).uniq
        keys = WeaponKey.where(slug: all_effects.filter_map(&:key_slug).uniq)

        return render_not_found_response('weapon_skill_family') if data.empty? && all_effects.empty? && versions.empty?

        render json: {
          weapon_skill_family: {
            modifier: modifier,
            display_name: display_name(versions),
            icon_stems: versions.filter_map(&:icon_stem).uniq,
            data: WeaponSkillDatumBlueprint.render_as_hash(data),
            effects: WeaponSkillEffectBlueprint.render_as_hash(all_effects),
            versions: versions_payload(versions),
            keys: WeaponKeyBlueprint.render_as_hash(keys),
            usage: {
              version_count: versions.size,
              weapon_count: versions.filter_map { |v| v.weapon_skill&.weapon_granblue_id }.uniq.size
            }
          }
        }
      end

      private

      # q must be a string (a 422 otherwise); has_effects and manually_edited
      # apply only when 'true'.
      def index_filters
        {
          query: (params.expect(:q).downcase if params[:q].present?),
          series: params[:series].presence,
          size: params[:size].presence,
          boost_type: params[:boost_type].presence,
          has_effects: params[:has_effects] == 'true',
          manually_edited: params[:manually_edited] == 'true'
        }
      end

      # Same "only when every version agrees" rule as the index
      # (WeaponSkillFamilyIndex), applied to one family's already-loaded versions.
      def display_name(versions)
        distinct = versions.map { |v| [v.name_en, v.name_jp] }.uniq
        return { en: params[:modifier], ja: nil } unless distinct.size == 1

        (en, ja) = distinct.first
        { en: en || params[:modifier], ja: ja }
      end

      def versions_payload(versions)
        versions.sort_by { |v| [v.weapon_skill&.weapon&.name_en.to_s, v.ordinal] }.map do |v|
          weapon = v.weapon_skill&.weapon
          Api::V1::WeaponSkillVersionBlueprint.render_as_hash(v).merge(
            id: v.id,
            skill_id: v.skill_id,
            weapon: weapon && { granblue_id: weapon.granblue_id, name_en: weapon.name_en,
                                element: weapon.element, rarity: weapon.rarity,
                                proficiency: weapon.proficiency,
                                weapon_series_id: weapon.weapon_series_id,
                                latest_date: weapon.latest_date }
          )
        end
      end
    end
  end
end
