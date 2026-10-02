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

      def load_items
        ApplicationRecord.transaction(isolation: :repeatable_read) do
          characters = Character.pluck(:granblue_id, :name_en, :name_jp).group_by(&:first)
          [Weapon, Summon].flat_map do |model|
            fields = %i[id granblue_id name_en name_jp rarity element promotions]
            fields << :recruits if model == Weapon
            model.where(rarity: [1, 2, 3]).pluck(*fields).map do |row|
              id, game_id, en, jp, rarity, element, promotions, recruits = row
              matches = characters[recruits] || []
              { 'identity' => "#{model.name}:#{id}", 'drawable_type' => model.name, 'drawable_id' => id,
                'granblue_id' => game_id, 'name' => { 'en' => en, 'ja' => jp }, 'rarity' => rarity,
                'element' => element, 'promotions' => (promotions || []).sort,
                'category' => if model == Summon
                                'summon'
                              else
                                (recruits.present? ? 'characterWeapon' : 'weapon')
                              end,
                'recruits' => matches.size == 1 ? { 'en' => matches.first[1], 'ja' => matches.first[2] } : nil }
            end
          end
        end
      end
    end
  end
end
