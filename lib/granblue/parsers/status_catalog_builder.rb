# frozen_string_literal: true

module Granblue
  module Parsers
    # Builds the normalized Status catalog from stored character wiki/game blobs.
    class StatusCatalogBuilder
      CATEGORY_PRIORITY = {
        'buff' => 0,
        'special' => 1,
        'debuff' => 2,
        'field' => 3
      }.freeze

      class << self
        def build_all(debug: false)
          records = {}

          Character.where.not(game_raw_en: [nil, {}]).or(Character.where.not(wiki_raw: [nil, ''])).find_each do |character|
            new(character).records.each do |record|
              key = record[:game_ailment_id].presence || "name:#{record[:name_en].downcase}"
              records[key] = merge_record(records[key], record)
            end
          rescue StandardError => e
            Rails.logger.error "[STATUS_CATALOG] #{character.granblue_id}: #{e.message}"
            puts "[STATUS_CATALOG] #{character.granblue_id}: #{e.message}" if debug
          end

          persist(records.values, debug: debug)
        end

        private

        def merge_record(existing, record)
          return record if existing.blank?

          existing.merge(record) do |key, old_value, new_value|
            key == :category ? strongest_category(old_value, new_value) : old_value.presence || new_value
          end
        end

        def persist(records, debug:)
          created = 0
          updated = 0

          records.each do |attrs|
            status = find_status(attrs)
            was_new = status.new_record?
            attrs = attrs.merge(category: strongest_category(status.category, attrs[:category])) unless was_new

            status.assign_attributes(attrs.compact)
            next unless status.changed?

            status.save!
            was_new ? created += 1 : updated += 1
            puts "[STATUS_CATALOG] #{was_new ? 'created' : 'updated'} #{status.name_en}" if debug
          end

          { created: created, updated: updated, total: Status.count }
        end

        def find_status(attrs)
          if attrs[:game_ailment_id].present?
            Status.find_or_initialize_by(game_ailment_id: attrs[:game_ailment_id])
          else
            Status.find_or_initialize_by(name_en: attrs[:name_en])
          end
        end

        def strongest_category(left, right)
          return right if left.blank?
          return left if right.blank?

          CATEGORY_PRIORITY.fetch(left, 0) >= CATEGORY_PRIORITY.fetch(right, 0) ? left : right
        end
      end

      def initialize(character)
        @data = CharacterWikiData.new(character)
      end

      def records
        by_skill_records + fallback_wiki_records
      end

      private

      attr_reader :data

      def by_skill_records
        skill_keys.flat_map do |skill_key|
          names = status_names_from_text(params["#{skill_key}_effdesc"] || params["#{skill_key}_desc"])
          game_action = data.game_action(skill_key)
          jp_action = data.game_action(skill_key, lang: :jp)
          ailment_ids = data.csv(game_action&.dig('ailment'))
          categories = categories_for(game_action)

          jp_names = jp_status_names(jp_action)
          build_paired_records(names, ailment_ids, categories, jp_names)
        end
      end

      def fallback_wiki_records
        status_names_from_text(params.values.join("\n")).map do |name|
          status_attrs(name_en: name)
        end
      end

      def build_paired_records(names, ailment_ids, categories, jp_names)
        max = [names.size, ailment_ids.size].max

        max.times.filter_map do |index|
          name = names[index].presence || jp_names[index].presence
          next if name.blank?

          status_attrs(
            name_en: clean_status_name(name),
            name_jp: jp_names[index],
            game_ailment_id: ailment_ids[index],
            category: categories[index]
          )
        end
      end

      def status_attrs(name_en:, name_jp: nil, game_ailment_id: nil, category: nil)
        family, level = Status.split_family_and_level(name_en)

        {
          game_ailment_id: game_ailment_id,
          name_en: name_en,
          name_jp: name_jp,
          family: family,
          level: level,
          category: category.presence || infer_category(name_en),
          wiki_slug: name_en.tr(' ', '_')
        }
      end

      def categories_for(game_action)
        details = game_action&.dig('ability_detail')
        return [] unless details.is_a?(Hash)

        details.flat_map do |category, entries|
          Array(entries).map { normalize_category(category) }
        end
      end

      def normalize_category(category)
        case category.to_s
        when /debuff/i then 'debuff'
        when /field/i then 'field'
        else 'buff'
        end
      end

      def infer_category(name)
        normalized = name.to_s.downcase

        if normalized.match?(/lowered|down|delay|petrified|paralyzed|poison|charmed|sleep|blind|fear/)
          'debuff'
        elsif normalized.include?('field')
          'field'
        else
          'buff'
        end
      end

      def status_names_from_text(text)
        text.to_s.scan(CharacterWikiData::STATUS_TEMPLATE).filter_map do |match|
          clean_status_name(match.first.split('|').first)
        end.uniq
      end

      def clean_status_name(name)
        name.to_s.strip.gsub(/\AStatus\|/i, '')
      end

      def jp_status_names(jp_action)
        details = jp_action&.dig('ability_detail')
        return [] unless details.is_a?(Hash)

        details.values.flatten.filter_map do |entry|
          next unless entry.is_a?(Hash)

          entry['name'].presence || entry['status_name'].presence
        end
      end

      def skill_keys
        params.keys.grep(/\A(?:a\d+[a-z]?|ougi\d*|sa\d*)_(?:effdesc|desc)\z/).map do |key|
          key.sub(/_(?:effdesc|desc)\z/, '')
        end.uniq
      end

      def params
        data.params
      end
    end
  end
end
