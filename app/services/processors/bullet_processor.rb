# frozen_string_literal: true

module Processors
  class BulletProcessor < BaseProcessor
    def process
      bullet_info = extract_bullet_info
      return unless bullet_info

      set_bullets = bullet_info['set_bullets']
      return unless set_bullets.is_a?(Hash)

      weapon_granblue_id = set_bullets['weapon_id']&.to_s
      return unless weapon_granblue_id.present?

      grid_weapon = find_grid_weapon(weapon_granblue_id)
      unless grid_weapon
        Rails.logger.warn "[BULLET] No grid weapon found for weapon_id #{weapon_granblue_id}"
        return
      end

      grid_weapon.grid_weapon_bullets.destroy_all

      bullet_entries(set_bullets).each do |position, bullet_data|
        create_grid_weapon_bullet(grid_weapon, bullet_data, position)
      end

      sync_to_collection(grid_weapon)
    end

    private

    def extract_bullet_info
      @data = @data.with_indifferent_access if @data.is_a?(Hash)
      info = @data['bullet_info']
      return nil if info.blank? || info.is_a?(Array)

      info
    end

    def find_grid_weapon(weapon_granblue_id)
      @party.weapons.joins(:weapon).find_by(weapons: { granblue_id: weapon_granblue_id })
    end

    def bullet_entries(set_bullets)
      set_bullets.select { |key, _| key.match?(/\Abullet_\d+\z/) }
                 .sort_by { |key, _| key.scan(/\d+/).first.to_i }
                 .map { |key, data| [key.scan(/\d+/).first.to_i - 1, data] }
    end

    def create_grid_weapon_bullet(grid_weapon, bullet_data, position)
      granblue_id = bullet_data['bullet_id']&.to_s
      return unless granblue_id.present?

      bullet = Bullet.find_by(granblue_id: granblue_id)
      unless bullet
        Rails.logger.warn "[BULLET] Bullet not found with granblue_id #{granblue_id}"
        return
      end

      grid_weapon.grid_weapon_bullets.create!(bullet: bullet, position: position)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "[BULLET] Failed to create GridWeaponBullet: #{e.record.errors.full_messages.join(', ')}"
    end

    def sync_to_collection(grid_weapon)
      collection_weapon = grid_weapon.collection_weapon
      return unless collection_weapon

      collection_weapon.collection_weapon_bullets.destroy_all
      grid_weapon.grid_weapon_bullets.reload.each do |gwb|
        collection_weapon.collection_weapon_bullets.create!(bullet_id: gwb.bullet_id, position: gwb.position)
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "[BULLET] Failed to sync CollectionWeaponBullet: #{e.record.errors.full_messages.join(', ')}"
      end
    end
  end
end
