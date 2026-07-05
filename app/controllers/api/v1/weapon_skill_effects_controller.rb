# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillEffectsController < Api::V1::ApiController
      include Concerns::WeaponSkillRowGuard

      before_action :ensure_editor_role, only: %i[create update destroy]
      before_action :set, only: %i[update destroy]

      # GET /weapon_skill_effects
      def index
        effects = WeaponSkillEffect.all
        effects = effects.where(modifier: params[:modifier]) if params[:modifier].present?
        effects = effects.where(boost_type: params[:boost_type]) if params[:boost_type].present?
        effects = effects.where(key_slug: params[:key_slug]) if params[:key_slug].present?
        render json: WeaponSkillEffectBlueprint.render(effects.order(:modifier, :boost_type),
                                                       root: :weapon_skill_effects)
      end

      # POST /weapon_skill_effects
      def create
        effect = WeaponSkillEffect.new(effect_params)
        effect.manually_edited_at = Time.current
        effect.save!
        render json: WeaponSkillEffectBlueprint.render(effect), status: :created
      end

      # PATCH /weapon_skill_effects/:id
      def update
        @effect.assign_attributes(effect_params)
        @effect.manually_edited_at = Time.current
        @effect.save!
        render json: WeaponSkillEffectBlueprint.render(@effect)
      end

      # DELETE /weapon_skill_effects/:id — 409 with blast radius unless force=true
      def destroy
        guarded_destroy(@effect)
      end

      private

      def set
        @effect = WeaponSkillEffect.find(params[:id])
      end

      def effect_params
        permitted = params.require(:weapon_skill_effect)
                          .permit(:modifier, :boost_type, :series, :scaling_kind, :value, :value_unit,
                                  :per_copy_cap, :total_cap, :shared_cap_group, :cap_formula,
                                  :count_basis, :count_cap, :target_instance, :aura_boostable,
                                  :stacking, :applies_to, :notes, :key_slug, :frame_rule,
                                  :weapon_skill_version_id, condition: {})
        if params[:weapon_skill_effect].key?(:condition) && params[:weapon_skill_effect][:condition].nil?
          permitted[:condition] = nil
        end
        permitted
      end
    end
  end
end
