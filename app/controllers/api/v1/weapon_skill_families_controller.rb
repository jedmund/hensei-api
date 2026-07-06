# frozen_string_literal: true

module Api
  module V1
    # Weapon-skill FAMILIES: the modifier-keyed aggregate the calculator
    # resolves values through. A family is a virtual resource over the
    # canonical weapon_skill_data / weapon_skill_effects rows, the
    # weapon_skill_versions classified into it, and the weapon keys whose
    # effects reference it.
    class WeaponSkillFamiliesController < Api::V1::ApiController
      # GET /weapon_skill_families
      def index
        families = build_families
        families = apply_filters(families)
        render json: { weapon_skill_families: families.sort_by { |f| f[:modifier].downcase } }
      end

      # GET /weapon_skill_families/:modifier
      def show
        modifier = params[:modifier]
        data = WeaponSkillDatum.where(modifier: modifier).order(:boost_type, :series, :size)
        effects = WeaponSkillEffect.where(modifier: modifier).order(:boost_type)
        versions = WeaponSkillVersion.includes(:skill, weapon_skill: :weapon)
                                     .where(skill_modifier: modifier)
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

      def build_families
        data_rows = WeaponSkillDatum.all.to_a
        effect_rows = WeaponSkillEffect.where(weapon_skill_version_id: nil).to_a
        version_stats = WeaponSkillVersion.joins(:weapon_skill)
                                          .where.not(skill_modifier: [nil, ''])
                                          .group(:skill_modifier)
                                          .pluck(:skill_modifier,
                                                 Arel.sql('COUNT(*)'),
                                                 Arel.sql('COUNT(DISTINCT weapon_skills.weapon_granblue_id)'))
                                          .to_h { |mod, versions, weapons| [mod, { versions: versions, weapons: weapons }] }
        names = family_display_names
        icon_stems = family_icon_stems

        modifiers = (data_rows.map(&:modifier) + effect_rows.map(&:modifier) + version_stats.keys).compact.uniq
        modifiers.map do |mod|
          d = data_rows.select { |r| r.modifier == mod }
          e = effect_rows.select { |r| r.modifier == mod }
          stats = version_stats[mod] || { versions: 0, weapons: 0 }
          {
            modifier: mod,
            display_name: names[mod],
            icon_stems: icon_stems[mod] || [],
            boost_types: (d.map(&:boost_type) + e.map(&:boost_type)).uniq.sort,
            series: (d.filter_map(&:series) + e.filter_map(&:series)).uniq.sort,
            sizes: d.filter_map(&:size).uniq.sort,
            formula_types: d.filter_map(&:formula_type).uniq.sort,
            counts: { data_rows: d.size, effect_rows: e.size,
                      versions: stats[:versions], weapons: stats[:weapons] },
            manually_edited: (d + e).any?(&:manually_edited_at)
          }
        end
      end

      # Linked skill name per family, but only when every version agrees on one —
      # names like "Tsunami's Aegis" / "Mountain's Aegis" are per-weapon flavor
      # text for the same mechanical family, so a family spanning several of
      # them has no single true name (falls back to the modifier instead).
      def family_display_names
        rows = WeaponSkillVersion.joins(:skill)
                                 .where.not(skill_modifier: [nil, ''])
                                 .group(:skill_modifier, 'skills.name_en', 'skills.name_jp')
                                 .pluck(:skill_modifier, 'skills.name_en', 'skills.name_jp')
        rows.group_by { |mod, _, _| mod }.each_with_object({}) do |(mod, entries), out|
          next unless entries.size == 1

          (_, en, ja) = entries.first
          out[mod] = { en: en, ja: ja }
        end
      end

      # All distinct resolvable icon stems per family — a family can carry more than
      # one when versions resolve to different element/type art (e.g. Aegis's
      # per-element icons), and the frontend cycles through them for those.
      def family_icon_stems
        versions = WeaponSkillVersion.joins(weapon_skill: :weapon)
                                     .where.not(skill_modifier: [nil, ''])
                                     .includes(weapon_skill: :weapon)
        versions.each_with_object(Hash.new { |h, k| h[k] = [] }) do |v, out|
          stem = v.icon_stem
          next if stem.blank?

          out[v.skill_modifier] << stem unless out[v.skill_modifier].include?(stem)
        end
      end

      def apply_filters(families)
        if params[:q].present?
          q = params[:q].downcase
          families = families.select do |f|
            f[:modifier].downcase.include?(q) ||
              f[:display_name]&.values&.any? { |n| n&.downcase&.include?(q) }
          end
        end
        families = families.select { |f| f[:series].include?(params[:series]) } if params[:series].present?
        families = families.select { |f| f[:sizes].include?(params[:size]) } if params[:size].present?
        families = families.select { |f| f[:boost_types].include?(params[:boost_type]) } if params[:boost_type].present?
        families = families.select { |f| f[:counts][:effect_rows].positive? } if params[:has_effects] == 'true'
        families = families.select { |f| f[:manually_edited] } if params[:manually_edited] == 'true'
        families
      end

      # Same "only when every version agrees" rule as family_display_names,
      # applied to one family's already-loaded versions.
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
