# frozen_string_literal: true

require 'digest'
module GachaSimulation
  class Catalogue
    LOCK = Mutex.new
    class << self
      def snapshot
        LOCK.synchronize do
          now = Time.now.to_i
          return @snapshot if @snapshot && now - @snapshot['loaded_at'] < 900

          begin
            items = load_items.sort_by { |item| item['identity'] }
            raise Unavailable, 'Empty catalogue' if items.empty?

            @snapshot = deep_freeze({ 'items' => items, 'loaded_at' => now,
                                      'fingerprint' => Digest::SHA256.hexdigest(JSON.generate(items)) })
          rescue StandardError => e
            Rails.logger.warn("gacha catalogue refresh failed: #{e.class}")
            raise Unavailable, 'Catalogue temporarily unavailable' unless @snapshot && now - @snapshot['loaded_at'] <= 3600

            @snapshot
          end
        end
      end

      def deep_freeze(value)
        case value
        when Hash then value.each { |key, child|
          deep_freeze(key)
          deep_freeze(child)
        }
        when Array then value.each { |child| deep_freeze(child) }
        end
        value.freeze
      end

      # The recruited character, with the season and series its tags show
      def recruit(character)
        series = character.ordered_series_records.map do |record|
          { 'id' => record.id, 'slug' => record.slug, 'name' => { 'en' => record.name_en, 'ja' => record.name_jp } }
        end
        { 'granblue_id' => character.granblue_id, 'en' => character.name_en, 'ja' => character.name_jp,
          'season' => character.season, 'series' => series.presence || character.series }
      end

      def load_items
        ApplicationRecord.transaction(isolation: :repeatable_read) do
          # Style Shift rows share their base character's granblue_id; the weapon
          # recruits the base character
          characters = Character.where(style_swap: false).includes(:character_series_records).group_by(&:granblue_id)
          [Weapon, Summon].flat_map do |model|
            fields = %i[id granblue_id name_en name_jp rarity element promotions release_date]
            fields << :recruits if model == Weapon
            model.where(rarity: [1, 2, 3]).pluck(*fields).map do |row|
              id, game_id, en, jp, rarity, element, promotions, release_date, recruits = row
              matches = characters[recruits] || []
              { 'identity' => "#{model.name}:#{id}", 'drawable_type' => model.name, 'drawable_id' => id,
                'granblue_id' => game_id, 'name' => { 'en' => en, 'ja' => jp }, 'rarity' => rarity,
                'element' => element, 'promotions' => (promotions || []).sort, 'release_date' => release_date&.iso8601,
                'category' => if model == Summon
                                'summon'
                              else
                                (recruits.present? ? 'characterWeapon' : 'weapon')
                              end,
                'recruits' => (recruit(matches.first) if matches.size == 1) }
            end
          end
        end
      end
    end
  end
end
