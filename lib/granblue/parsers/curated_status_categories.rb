# frozen_string_literal: true

module Granblue
  module Parsers
    # The user-reviewed corrections for status names whose category or game display id
    # can't be derived from the stored sources. data/statuses/categories.json is a list of
    # { name_en, category?, game_status_id?, reason }: game_status_id is a display id
    # ("1020", "1019_0_40") or "none" for a status the game has no id for (an instant effect
    # such as Charge Boost). The status catalogue applies them after building; a curated
    # value always wins.
    class CuratedStatusCategories
      DEFAULT_PATH = Rails.root.join('data/statuses/categories.json')
      CATEGORIES = %w[buff debuff field].freeze
      NO_ID = 'none'
      GAME_STATUS_ID = /\A(?:\d+(?:_\d+)*|#{NO_ID})\z/

      class Invalid < StandardError; end

      # → { normalized name => { category:, game_status_id: } }. A missing or empty file means
      # nothing is curated.
      def self.load(path = DEFAULT_PATH)
        return {} unless File.file?(path) && File.size(path).positive?

        new(JSON.parse(File.read(path)), path).to_h
      rescue JSON::ParserError => e
        raise Invalid, "#{path}: #{e.message}"
      end

      # The committed file's digest ("-" when missing): effects read curated categories, so the
      # build fingerprint covers it.
      def self.sha256(path = DEFAULT_PATH)
        return '-' unless File.file?(path)

        stamp = [path.to_s, File.mtime(path), File.size(path)]
        @sha256 = nil unless @sha256_stamp == stamp
        @sha256_stamp = stamp
        @sha256 ||= Digest::SHA256.file(path).hexdigest
      end

      def initialize(entries, path)
        @entries = entries
        @path = path
      end

      def to_h
        raise Invalid, "#{@path}: expected a list of entries" unless @entries.is_a?(Array)

        @entries.each_with_index.with_object({}) do |(entry, index), curated|
          name, values = validate(entry, index)
          key = Status.normalize_name(name)
          raise Invalid, "#{@path}: #{name.inspect} is listed twice" if curated.key?(key)

          curated[key] = values
        end
      end

      private

      def validate(entry, index)
        raise Invalid, "#{@path}: entry #{index} isn't an object" unless entry.is_a?(Hash)

        name, category, game_status_id, reason = entry.values_at('name_en', 'category', 'game_status_id', 'reason')
        raise Invalid, "#{@path}: entry #{index} has no name_en" if name.blank?
        raise Invalid, "#{@path}: #{name.inspect} has no reason" if reason.blank?
        raise Invalid, "#{@path}: #{name.inspect} sets neither category nor game_status_id" if category.nil? && game_status_id.nil?
        if category && !CATEGORIES.include?(category)
          raise Invalid, "#{@path}: #{name.inspect} has category #{category.inspect}"
        end
        if game_status_id && !GAME_STATUS_ID.match?(game_status_id.to_s)
          raise Invalid, "#{@path}: #{name.inspect} has game_status_id #{game_status_id.inspect}"
        end

        [name, { category: category, game_status_id: game_status_id&.to_s }]
      end
    end
  end
end
