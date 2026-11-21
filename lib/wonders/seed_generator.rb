# frozen_string_literal: true

require 'cgi'
require 'json'
require_relative 'wiki_page'

module Wonders
  ##
  # Builds the Wonders catalogue seed (db/data/wonders/catalogue.json) offline.
  #
  # - The gbf.wiki "Wonders" page is the master list: every Wonder on it is
  #   seeded, in its order, under the category its section maps to.
  # - The game captures (`/item/memorial_list/1` responses, any number of
  #   accounts, in EN and JA) are merged by item_id: the union of their
  #   Wonders, with each field from whichever capture has it. EN captures are
  #   joined to the wiki by name; the overrides' ids cover the rest. Game text
  #   wins over wiki text wherever a capture has it, and gives the effects'
  #   action_ids.
  # - The overrides file (db/data/wonders/overrides.yml) gives ids to Wonders
  #   the captures don't have, and fills or corrects fields per granblue_id.
  # - Per-level bonuses, evolution caps, elements, kinds and the
  #   battle-relevant list are the tables below (GBF-282).
  #
  # Pure: no database and no network. Raises when a wiki Wonder has no id, or
  # a captured Wonder isn't on the wiki, so new Wonders get noticed.
  class SeedGenerator
    class Error < StandardError; end

    RINGS_OF_FATE = '8'

    ELEMENTS = { 'fire' => 1, 'water' => 2, 'earth' => 3, 'wind' => 4, 'light' => 5, 'dark' => 6 }.freeze

    # granblue_id => [element, the element whose resistance it gives]
    SEALS = {
      '9009' => %w[fire wind], '9008' => %w[water fire], '9007' => %w[earth water],
      '9006' => %w[wind earth], '9010' => %w[light dark], '9011' => %w[dark light]
    }.freeze
    # Level => [stat, value]; :resistance is the Seal's resistance element.
    SEAL_LEVELS = [
      [:resistance, 5], ['def', 3], ['double_attack_rate', 3], ['healing_cap', 3], ['debuff_resistance', 3],
      ['def', 3], ['triple_attack_rate', 3], ['healing_cap', 3], ['debuff_resistance', 3], ['debuff_success_rate', 5],
      ['def', 3], ['healing_cap', 3], ['double_attack_rate', 3], ['debuff_resistance', 3], ['triple_attack_rate', 2],
      ['debuff_resistance', 1], ['def', 3], ['healing_cap', 3], ['triple_attack_rate', 2], [:resistance, 5]
    ].freeze
    SEAL_EVOLUTION_CAPS = { 0 => 10, 1 => 15, 2 => 18, 3 => 20 }.freeze

    # granblue_id => [element, the element its DMG Amplify targets]
    YUPEI = {
      '1001' => %w[fire wind], '1002' => %w[water fire], '1003' => %w[earth water],
      '1004' => %w[wind earth], '1005' => %w[light dark], '1006' => %w[dark light]
    }.freeze
    # :atk is the Yupei's element ATK; :amplify its DMG Amplify vs. element.
    YUPEI_LEVELS = [
      [:atk, 5], ['def', 5], ['skill_dmg', 5], ['ca_dmg', 5], [:atk, 5],
      ['def', 5], [:amplify, 5], ['na_dmg_cap', 5], ['skill_dmg_cap', 5], ['ca_dmg_cap', 5]
    ].freeze

    SCALING = %w[9015].freeze
    # Besides the Seals, the Yupei and every Ring of Fate
    BATTLE_RELEVANT = %w[9003 9013 9014 9015 9016 9017 29].freeze

    # Wiki values for a later damage calculation, by action_id. Displayed
    # text stays the game's.
    EFFECT_DETAILS = {
      109_003 => { 'targets' => 'eternals', 'hp' => 10, 'atk' => 10, 'charge_bar' => 10 },
      109_006 => { 'targets' => 'divine_generals', 'hp' => 10, 'atk' => 10, 'charge_bar' => 10 },
      109_008 => { 'chain_burst' => 5 },
      109_009 => { 'element_atk' => 3 },
      109_010 => { 'dmg_cap' => 3 },
      109_011 => { 'stat' => 'dmg_amplify', 'max' => 5 }
    }.freeze

    WONDER_OVERRIDE_FIELDS = %w[name_en name_jp description_en description_jp element battle_relevant].freeze
    EFFECT_OVERRIDE_FIELDS = %w[action_id text_en text_jp details].freeze
    DEFAULT_EN_CAPTURES = %w[spec/fixtures/wonders/memorial_list.en.json].freeze
    DEFAULT_JA_CAPTURES = %w[spec/fixtures/wonders/memorial_list.ja.json
                             spec/fixtures/wonders/memorial_list.ja.account2.json
                             spec/fixtures/wonders/memorial_list.ja.account3.json].freeze
    INVISIBLE = /[\u200B-\u200F\u202A-\u202E\u2060\uFEFF]/

    # @param wikitext [String] the gbf.wiki "Wonders" page
    # @param en_captures [Array<Array<Hash>>] EN memorial_list responses
    # @param ja_captures [Array<Array<Hash>>] JA memorial_list responses
    # @param overrides [Hash] parsed overrides.yml ({ 'ids' => {}, 'wonders' => {} })
    def initialize(wikitext:, en_captures:, ja_captures:, overrides: {})
      @wikitext = wikitext
      @en_captures = en_captures
      @ja_captures = ja_captures
      @overrides = overrides || {}
    end

    def self.normalize_name(name)
      name.to_s.gsub(INVISIBLE, '').gsub(/[[:space:]]+/, ' ').strip
    end

    # Game HTML (<br>, <font>) to plain text with newlines
    def self.sanitize_game_text(text)
      return nil if text.nil?

      plain = text.to_s.gsub(%r{<br\s*/?>}i, "\n").gsub(/<[^>]*>/, '')
      CGI.unescapeHTML(plain).lines.map(&:rstrip).join("\n").strip
    end

    # @return [Hash] { 'categories' => [...], 'wonders' => [...] }
    def catalogue
      { 'categories' => categories, 'wonders' => wonders }
    end

    def categories
      en_categories.values.each_with_index.map do |category, index|
        id = category['category_id'].to_s
        {
          'granblue_id' => id,
          'name_en' => self.class.normalize_name(category['name']),
          'name_jp' => self.class.normalize_name(ja_categories[id]&.dig('name')).presence,
          'category_type' => category['type'].to_i,
          'sort_order' => index + 1
        }
      end
    end

    def wonders
      rows = WikiPage.new(@wikitext).entries.map do |entry|
        id = en_items_by_name[entry[:name]]&.dig('item_id')&.to_s || override_ids[entry[:name]]
        raise Error, "No granblue_id for the wiki Wonder #{entry[:name].inspect}; add it to the overrides ids" unless id

        check_category(entry, en_items[id] || ja_items[id])
        apply_overrides(build_wonder(id, entry, en_items[id]))
      end

      unmatched = (en_items.keys | ja_items.keys) - rows.pluck('granblue_id')
      raise Error, "Captured Wonders not on the wiki: #{unmatched.join(', ')}" if unmatched.any?

      rows
    end

    private

    def check_category(entry, item)
      category = entry[:category]
      raise Error, "Category #{category} for #{entry[:name]} isn't in the captures" unless en_categories.key?(category)
      return if item.nil? || item['category_id'].to_s == category

      raise Error, "#{entry[:name]} is in category #{item['category_id']} in game but #{category} on the wiki"
    end

    def build_wonder(id, entry, item)
      ja_item = ja_items[id]
      kind = kind_for(id)
      effects = captured_effects(item, ja_item, entry)
      effects.each { |effect| effect['details'] = effect['details'].merge('no_stack_with_summon' => entry[:no_stack]) } if entry[:no_stack]

      {
        'granblue_id' => id,
        'category' => entry[:category],
        'name_en' => item ? self.class.normalize_name(item['name']) : entry[:name],
        'name_jp' => ja_item ? self.class.normalize_name(ja_item['name']) : nil,
        'description_en' => item ? self.class.sanitize_game_text(item['comment']) : entry[:description],
        'description_jp' => ja_item ? self.class.sanitize_game_text(ja_item['comment']) : nil,
        'kind' => kind,
        'max_level' => max_level_for(id),
        'max_evolution' => SEALS.key?(id) ? SEAL_EVOLUTION_CAPS.keys.max : 0,
        'element' => element_for(id, entry[:category], effects),
        'battle_relevant' => battle_relevant?(id, entry[:category]),
        'hidden_in_unite_and_fight' => SEALS.key?(id),
        'sort_order' => entry[:position],
        'effects' => effects,
        'level_bonuses' => level_bonuses_for(id),
        'evolution_caps' => evolution_caps_for(id)
      }
    end

    def kind_for(id)
      return 'leveled' if SEALS.key?(id) || YUPEI.key?(id)
      return 'scaling' if SCALING.include?(id)

      'fixed'
    end

    def max_level_for(id)
      return SEAL_LEVELS.size if SEALS.key?(id)

      YUPEI_LEVELS.size if YUPEI.key?(id)
    end

    def element_for(id, category, effects)
      return ELEMENTS.fetch(SEALS[id].first) if SEALS.key?(id)
      return ELEMENTS.fetch(YUPEI[id].first) if YUPEI.key?(id)
      return nil unless category == RINGS_OF_FATE

      named = effects.filter_map { |effect| effect['text_en'].to_s[/\b(fire|water|earth|wind|light|dark) allies/i, 1] }.first
      raise Error, "No element in the effects of Ring of Fate #{id}" unless named

      ELEMENTS.fetch(named.downcase)
    end

    def battle_relevant?(id, category)
      SEALS.key?(id) || YUPEI.key?(id) || BATTLE_RELEVANT.include?(id) || category == RINGS_OF_FATE
    end

    def level_bonuses_for(id)
      if SEALS.key?(id)
        resistance = SEALS[id].last
        SEAL_LEVELS.each_with_index.map do |(stat, value), index|
          { 'level' => index + 1, 'stat' => stat == :resistance ? "#{resistance}_resistance" : stat, 'value' => value }
        end
      elsif YUPEI.key?(id)
        element, target = YUPEI[id]
        stats = { atk: "#{element}_atk", amplify: "dmg_amplify_vs_#{target}" }
        YUPEI_LEVELS.each_with_index.map do |(stat, value), index|
          { 'level' => index + 1, 'stat' => stats.fetch(stat, stat), 'value' => value }
        end
      else
        []
      end
    end

    def evolution_caps_for(id)
      return [] unless SEALS.key?(id)

      SEAL_EVOLUTION_CAPS.map { |evolution, max_level| { 'evolution' => evolution, 'max_level' => max_level } }
    end

    # Effects by position: action_ids and text from the captures, EN text
    # from the wiki when no EN capture has the Wonder. Without any capture,
    # the wiki's effect lines with unknown action_ids.
    def captured_effects(item, ja_item, entry)
      en_actions = actions_by_position(item)
      ja_actions = actions_by_position(ja_item)
      positions = en_actions.keys | ja_actions.keys
      positions = (1..entry[:effect_lines].size).to_a if item.nil? && ja_item.nil?

      positions.sort.map do |position|
        action = en_actions[position] || ja_actions[position]
        action_id = action && action['action_id'].to_i
        {
          'position' => position,
          'action_id' => action_id,
          'text_en' => en_actions[position] ? self.class.sanitize_game_text(action['comment']) : entry[:effect_lines][position - 1],
          'text_jp' => ja_actions[position]&.then { |a| self.class.sanitize_game_text(a['comment']) },
          'details' => EFFECT_DETAILS.fetch(action_id, {}).dup
        }
      end
    end

    def actions_by_position(item)
      Array(item&.dig('action_list')).index_by { |action| action['action_no'].to_i }
    end

    # Override values win over the captures and the wiki, except those under
    # `derived:` (text inferred rather than seen in the game), which only
    # fill fields that are still blank, so real capture text replaces them
    # once a capture has it.
    def apply_overrides(wonder)
      override = override_wonders[wonder['granblue_id']]
      return wonder unless override

      apply_override_fields(wonder, override.except('derived'), derived: false)
      apply_override_fields(wonder, override['derived'], derived: true) if override['derived']
      wonder
    end

    def apply_override_fields(wonder, override, derived:)
      unknown = override.keys - WONDER_OVERRIDE_FIELDS - ['effects']
      raise Error, "Unknown override fields for #{wonder['granblue_id']}: #{unknown.join(', ')}" if unknown.any?

      WONDER_OVERRIDE_FIELDS.each { |field| assign_override(wonder, field, override[field], derived) }
      (override['effects'] || {}).each do |position, fields|
        apply_effect_override(wonder, position.to_i, fields || {}, derived)
      end
    end

    def apply_effect_override(wonder, position, fields, derived)
      unknown = fields.keys - EFFECT_OVERRIDE_FIELDS
      raise Error, "Unknown effect override fields for #{wonder['granblue_id']}: #{unknown.join(', ')}" if unknown.any?

      effect = wonder['effects'].find { |e| e['position'] == position }
      unless effect
        effect = { 'position' => position, 'action_id' => nil, 'text_en' => nil, 'text_jp' => nil, 'details' => {} }
        wonder['effects'] << effect
        wonder['effects'].sort_by! { |e| e['position'] }
      end
      EFFECT_OVERRIDE_FIELDS.each do |field|
        if field == 'details'
          effect['details'] = effect['details'].merge(fields['details']) if fields['details']
        else
          assign_override(effect, field, fields[field], derived)
        end
      end
    end

    def assign_override(target, field, value, derived)
      return if value.nil?
      return if derived && !target[field].nil?

      target[field] = value
    end

    def en_items_by_name
      @en_items_by_name ||= en_items.values.index_by { |item| self.class.normalize_name(item['name']) }
    end

    # item_id => item, merged over the captures: the first capture with a
    # Wonder gives it; later ones fill fields it doesn't have
    def en_items
      @en_items ||= merge_items(@en_captures)
    end

    def ja_items
      @ja_items ||= merge_items(@ja_captures)
    end

    def en_categories
      @en_categories ||= merge_categories(@en_captures)
    end

    def ja_categories
      @ja_categories ||= merge_categories(@ja_captures)
    end

    def merge_items(captures)
      captures.flat_map { |response| Array(response).flat_map { |category| Array(category['item']) } }
              .each_with_object({}) do |item, merged|
        id = item['item_id'].to_s
        merged[id] = merged.key?(id) ? fill_blanks(merged[id], item) : item
      end
    end

    def merge_categories(captures)
      captures.flat_map { |response| Array(response) }.each_with_object({}) do |category, merged|
        merged[category['category_id'].to_s] ||= category
      end
    end

    def fill_blanks(first, other)
      first.merge(other) { |_key, mine, theirs| mine.presence || theirs }
    end

    def override_ids
      @override_ids ||= (@overrides['ids'] || {}).to_h { |name, id| [self.class.normalize_name(name), id.to_s] }
    end

    def override_wonders
      @override_wonders ||= (@overrides['wonders'] || {}).transform_keys(&:to_s)
    end
  end
end
