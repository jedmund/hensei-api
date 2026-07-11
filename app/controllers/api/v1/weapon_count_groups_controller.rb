# frozen_string_literal: true

module Api
  module V1
    class WeaponCountGroupsController < Api::V1::ApiController
      before_action :ensure_editor_role, only: %i[create update destroy]
      before_action :set_group, only: %i[show update destroy]

      def index
        groups = WeaponCountGroup.includes(:weapons).order(:slug)
        groups = groups.where("slug ILIKE :q OR name_en ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

        render json: WeaponCountGroupBlueprint.render(groups, root: :weapon_count_groups)
      end

      def show
        render json: WeaponCountGroupBlueprint.render(@group)
      end

      def create
        permitted = group_params
        group = WeaponCountGroup.new(permitted.except(:weapon_granblue_ids))

        WeaponCountGroup.transaction do
          group.save!
          sync_memberships(group, permitted[:weapon_granblue_ids]) if permitted.key?(:weapon_granblue_ids)
        end

        render json: WeaponCountGroupBlueprint.render(group), status: :created
      end

      def update
        permitted = group_params
        WeaponCountGroup.transaction do
          @group.update!(permitted.except(:weapon_granblue_ids))
          sync_memberships(@group, permitted[:weapon_granblue_ids]) if permitted.key?(:weapon_granblue_ids)
        end

        render json: WeaponCountGroupBlueprint.render(@group)
      end

      def destroy
        @group.destroy!
        head :no_content
      end

      private

      def set_group
        @group = WeaponCountGroup.find_by(slug: params[:id]) || WeaponCountGroup.find(params[:id])
      end

      def group_params
        params.require(:weapon_count_group)
              .permit(:slug, :name_en, :name_jp, :notes, weapon_granblue_ids: [])
      end

      def sync_memberships(group, granblue_ids)
        ids = Array(granblue_ids).map(&:presence).compact.uniq
        weapons = Weapon.where(granblue_id: ids).index_by(&:granblue_id)
        missing = ids - weapons.keys
        if missing.any?
          raise ActiveRecord::RecordInvalid.new(group.tap do |record|
            record.errors.add(:base, "Unknown weapon granblue_id(s): #{missing.join(', ')}")
          end)
        end

        group.weapons = weapons.values
      end
    end
  end
end
