# frozen_string_literal: true

module Api
  module V1
    class BulletsController < Api::V1::ApiController
      before_action :doorkeeper_authorize!, only: %i[create update destroy]
      before_action :ensure_editor_role, only: %i[create update destroy]

      # GET /bullets
      def index
        bullets = Bullet.all
        bullets = bullets.by_type(params[:bullet_type]) if params[:bullet_type].present?
        bullets = bullets.order(:bullet_type, :order, :name_en)
        render json: BulletBlueprint.render(bullets, root: :bullets)
      end

      # GET /bullets/:id
      def show
        bullet = find_bullet
        return render_not_found_response('bullet') unless bullet

        render json: BulletBlueprint.render(bullet)
      end

      # POST /bullets
      def create
        bullet = Bullet.new(bullet_params)
        if bullet.save
          render json: BulletBlueprint.render(bullet), status: :created
        else
          render_validation_error_response(bullet)
        end
      end

      # PUT /bullets/:id
      def update
        bullet = find_bullet
        return render_not_found_response('bullet') unless bullet

        if bullet.update(bullet_params)
          render json: BulletBlueprint.render(bullet)
        else
          render_validation_error_response(bullet)
        end
      end

      # DELETE /bullets/:id
      def destroy
        bullet = find_bullet
        return render_not_found_response('bullet') unless bullet

        bullet.destroy
        head :no_content
      end

      private

      def find_bullet
        Bullet.find_by(granblue_id: params[:id]) || Bullet.find_by(id: params[:id])
      end

      def bullet_params
        params.permit(:name_en, :name_jp, :effect_en, :effect_jp, :granblue_id,
                      :slug, :bullet_type, :atk, :hits_all, :order)
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end
    end
  end
end
