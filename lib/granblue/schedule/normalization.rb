# frozen_string_literal: true

module Granblue
  module Schedule
    # Shared pieces of the normalized schedule record both sources produce:
    #
    #   { name_en:, name_jp:, starts_at:, ends_at:, kind_guess:, element:,
    #     image_en:, image_jp:, source:, source_id:, raw: }
    #
    # Times are ActiveSupport::TimeWithZone in Asia/Tokyo. element is a
    # GranblueEnums::ELEMENTS key name as a string ("Fire"), the BOSS element, or
    # nil. kind_guess is one of KINDS, or nil when the source gives no usable hint.
    module Normalization
      # Suggestions only; editors set the final kind.
      KINDS = %w[story_event rerun collab unite_and_fight dread_barrage farming alchemy other].freeze
      RECORD_KEYS = %i[name_en name_jp starts_at ends_at kind_guess element
                       image_en image_jp source source_id raw].freeze

      ELEMENT_NAMES = (GranblueEnums::ELEMENTS.keys.map(&:to_s) - ['Null']).freeze

      # Japanese element names as the official site writes them (火属性 etc.).
      JA_ELEMENTS = {
        '火' => 'Fire', '水' => 'Water', '土' => 'Earth',
        '風' => 'Wind', '光' => 'Light', '闇' => 'Dark'
      }.freeze

      # An event's element is the BOSS's element (as on events and gw_events).
      # Players bring the element advantaged against it: Fire > Wind > Earth >
      # Water > Fire, Light <> Dark. Boss element → the element to bring.
      ADVANTAGE_BY_BOSS = {
        'Water' => 'Earth', 'Fire' => 'Water', 'Earth' => 'Wind',
        'Wind' => 'Fire', 'Light' => 'Dark', 'Dark' => 'Light'
      }.freeze
      BOSS_BY_ADVANTAGE = ADVANTAGE_BY_BOSS.invert.freeze

      module_function

      # Boss element → the element players bring ("Water" → "Earth"); nil passes through.
      def advantage_for(boss)
        ADVANTAGE_BY_BOSS[boss]
      end

      # The element players bring → the boss element ("Fire" → "Wind").
      def boss_for(advantage)
        BOSS_BY_ADVANTAGE[advantage]
      end

      def jst
        ActiveSupport::TimeZone['Asia/Tokyo']
      end

      # "fire", "Fire", " FIRE " → "Fire"; anything else → nil.
      def element_name(value)
        text = value.to_s.strip
        return nil if text.empty?

        ELEMENT_NAMES.find { |name| name.casecmp?(text) }
      end

      def record(**attrs)
        RECORD_KEYS.index_with { |key| attrs[key] }
      end
    end
  end
end
