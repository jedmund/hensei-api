# frozen_string_literal: true

module Api
  module V1
    class ImportController < Api::V1::ApiController
      ELEMENT_MAPPING = {
        0 => nil,
        1 => 4,
        2 => 2,
        3 => 3,
        4 => 1,
        5 => 6,
        6 => 5
      }.freeze

      def create
        Rails.logger.info "[IMPORT] Starting import..."

        # Parse JSON request body
        raw_body = request.raw_post
        begin
          raw_params = JSON.parse(raw_body) if raw_body.present?
          Rails.logger.info "[IMPORT] Raw game data: #{raw_params.inspect}"
        rescue JSON::ParserError => e
          Rails.logger.error "[IMPORT] Invalid JSON in request body: #{e.message}"
          render json: { error: 'Invalid JSON data' }, status: :bad_request
          return
        end

        if raw_params.nil? || !raw_params.is_a?(Hash)
          Rails.logger.error "[IMPORT] Missing or invalid game data"
          render json: { error: 'Missing or invalid game data' }, status: :bad_request
          return
        end

        # Transform game data
        transformer = ::Granblue::Transformers::BaseDeckTransformer.new(raw_params)
        transformed_data = transformer.transform
        Rails.logger.info "[IMPORT] Transformed data: #{transformed_data.inspect}"

        # Validate transformed data
        unless transformed_data[:name].present? && transformed_data[:lang].present?
          Rails.logger.error "[IMPORT] Missing required fields in transformed data"
          render json: { error: 'Missing required fields name or lang' }, status: :unprocessable_entity
          return
        end

        # Create party
        party = Party.new(user: current_user)

        ActiveRecord::Base.transaction do
          # Basic party data
          party.name = transformed_data[:name]
          party.extra = transformed_data[:extra]
          party.save!

          # Process job and skills
          if transformed_data[:class].present?
            process_job(party, transformed_data[:class], transformed_data[:subskills])
          end

          # Process characters
          if transformed_data[:characters].present?
            process_characters(party, transformed_data[:characters])
          end

          # Process weapons
          if transformed_data[:weapons].present?
            process_weapons(party, transformed_data[:weapons])
          end

          # Process summons
          if transformed_data[:summons].present?
            process_summons(party, transformed_data[:summons], transformed_data[:friend_summon])
          end

          # Process sub summons
          if transformed_data[:sub_summons].present?
            process_sub_summons(party, transformed_data[:sub_summons])
          end
        end

        # Return shortcode for redirection
        render json: { shortcode: party.shortcode }, status: :created
      rescue StandardError => e
        Rails.logger.error "[IMPORT] Error processing import: #{e.message}"
        Rails.logger.error "[IMPORT] Backtrace: #{e.backtrace.join("\n")}"
        render json: { error: 'Error processing import' }, status: :unprocessable_entity
      end

      private

      def process_job(party, job_name, subskills)
        return unless job_name
        job = Job.find_by("name_en = ? OR name_jp = ?", job_name, job_name)
        unless job
          Rails.logger.warn "[IMPORT] Could not find job: #{job_name}"
          return
        end

        party.job = job
        party.save!
        Rails.logger.info "[IMPORT] Assigned job=#{job_name} to party_id=#{party.id}"

        return unless subskills&.any?
        subskills.each_with_index do |skill_name, idx|
          next if skill_name.blank?
          skill = JobSkill.find_by("(name_en = ? OR name_jp = ?) AND job_id = ?", skill_name, skill_name, job.id)
          unless skill
            Rails.logger.warn "[IMPORT] Could not find skill=#{skill_name} for job_id=#{job.id}"
            next
          end
          party["skill#{idx + 1}_id"] = skill.id
          Rails.logger.info "[IMPORT] Assigned skill=#{skill_name} at position #{idx + 1}"
        end
      end

      def process_characters(party, characters)
        return unless characters&.any?
        Rails.logger.info "[IMPORT] Processing #{characters.length} characters"

        characters.each_with_index do |char_data, idx|
          character = Character.find_by(granblue_id: char_data[:id])
          unless character
            Rails.logger.warn "[IMPORT] Character not found: #{char_data[:id]}"
            next
          end

          GridCharacter.create!(
            party: party,
            character_id: character.id,
            position: idx,
            uncap_level: char_data[:uncap],
            perpetuity: char_data[:ringed] || false,
            transcendence_step: char_data[:transcend] || 0
          )
          Rails.logger.info "[IMPORT] Added character: #{character.name_en} at position #{idx}"
        end
      end

      def process_weapons(party, weapons)
        return unless weapons&.any?
        Rails.logger.info "[IMPORT] Processing #{weapons.length} weapons"

        weapons.each_with_index do |weapon_data, idx|
          weapon = Weapon.find_by(granblue_id: weapon_data[:id])
          unless weapon
            Rails.logger.warn "[IMPORT] Weapon not found: #{weapon_data[:id]}"
            next
          end

          grid_weapon = GridWeapon.create!(
            party: party,
            weapon_id: weapon.id,
            position: idx - 1,
            mainhand: idx.zero?,
            uncap_level: weapon_data[:uncap],
            transcendence_step: weapon_data[:transcend] || 0,
            element: weapon_data[:attr] ? ELEMENT_MAPPING[weapon_data[:attr]] : nil
          )

          process_weapon_keys(grid_weapon, weapon_data[:keys]) if weapon_data[:keys]
          process_weapon_ax(grid_weapon, weapon_data[:ax]) if weapon_data[:ax]

          Rails.logger.info "[IMPORT] Added weapon: #{weapon.name_en} at position #{idx - 1}"
        end
      end

      def process_weapon_keys(grid_weapon, keys)
        keys.each_with_index do |key_id, idx|
          key = WeaponKey.find_by(granblue_id: key_id)
          unless key
            Rails.logger.warn "[IMPORT] WeaponKey not found: #{key_id}"
            next
          end
          grid_weapon["weapon_key#{idx + 1}_id"] = key.id
          grid_weapon.save!
        end
      end

      def process_weapon_ax(grid_weapon, ax_skills)
        ax_skills.each_with_index do |ax, idx|
          grid_weapon["ax_modifier#{idx + 1}"] = ax[:id].to_i
          grid_weapon["ax_strength#{idx + 1}"] = ax[:val].to_s.gsub(/[+%]/, '').to_i
        end
        grid_weapon.save!
      end

      def process_summons(party, summons, friend_summon = nil)
        return unless summons&.any?
        Rails.logger.info "[IMPORT] Processing #{summons.length} summons"

        # Main and sub summons
        summons.each_with_index do |summon_data, idx|
          summon = Summon.find_by(granblue_id: summon_data[:id])
          unless summon
            Rails.logger.warn "[IMPORT] Summon not found: #{summon_data[:id]}"
            next
          end

          grid_summon = GridSummon.new(
            party: party,
            summon_id: summon.id,
            position: idx,
            main: idx.zero?,
            friend: false,
            uncap_level: summon_data[:uncap],
            transcendence_step: summon_data[:transcend] || 0,
            quick_summon: summon_data[:qs] || false
          )

          if grid_summon.save
            Rails.logger.info "[IMPORT] Added summon: #{summon.name_en} at position #{idx}"
          else
            Rails.logger.error "[IMPORT] Failed to save summon: #{grid_summon.errors.full_messages}"
          end
        end

        # Friend summon if provided
        process_friend_summon(party, friend_summon) if friend_summon.present?
      end

      def process_friend_summon(party, friend_summon)
        friend = Summon.find_by("name_en = ? OR name_jp = ?", friend_summon, friend_summon)
        unless friend
          Rails.logger.warn "[IMPORT] Friend summon not found: #{friend_summon}"
          return
        end

        grid_summon = GridSummon.new(
          party: party,
          summon_id: friend.id,
          position: 6,
          main: false,
          friend: true,
          uncap_level: friend.ulb ? 5 : (friend.flb ? 4 : 3)
        )

        if grid_summon.save
          Rails.logger.info "[IMPORT] Added friend summon: #{friend.name_en}"
        else
          Rails.logger.error "[IMPORT] Failed to save friend summon: #{grid_summon.errors.full_messages}"
        end
      end

      def process_sub_summons(party, sub_summons)
        return unless sub_summons&.any?
        Rails.logger.info "[IMPORT] Processing #{sub_summons.length} sub summons"

        sub_summons.each_with_index do |summon_data, idx|
          summon = Summon.find_by(granblue_id: summon_data[:id])
          unless summon
            Rails.logger.warn "[IMPORT] Sub summon not found: #{summon_data[:id]}"
            next
          end

          grid_summon = GridSummon.new(
            party: party,
            summon_id: summon.id,
            position: idx + 5,
            main: false,
            friend: false,
            uncap_level: summon_data[:uncap],
            transcendence_step: summon_data[:transcend] || 0
          )

          if grid_summon.save
            Rails.logger.info "[IMPORT] Added sub summon: #{summon.name_en} at position #{idx + 5}"
          else
            Rails.logger.error "[IMPORT] Failed to save sub summon: #{grid_summon.errors.full_messages}"
          end
        end
      end
    end
  end
end
