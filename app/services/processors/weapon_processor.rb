# frozen_string_literal: true

module Processors
  ##
  # WeaponProcessor processes weapon data from a deck JSON and creates GridWeapon records.
  # It follows a similar error‐handling and implementation strategy as SummonProcessor.
  #
  # Expected data format (excerpt):
  # {
  #   "deck": {
  #     "pc": {
  #       "weapons": {
  #         "1": {
  #           "param": {
  #             "uncap": 3,
  #             "level": "150",
  #             "augment_skill_info": [ [ { "skill_id": 1588, "effect_value": "3", "show_value": "3%" }, ... ] ],
  #             "arousal": {
  #               "is_arousal_weapon": true,
  #               "level": 4,
  #               "skill": [ { "skill_id": 1896, ... }, ... ]
  #             },
  #             ...
  #           },
  #           "master": {
  #             "id": "1040215100",
  #             "name": "Wamdus's Cnidocyte",
  #             "attribute": "2",
  #             ...
  #           },
  #           "keys": [ "..." ]  // optional
  #         },
  #         "2": { ... },
  #         ...
  #       }
  #     }
  #   }
  # }
  #
  # The processor also uses an AX_MAPPING to convert in‐game AX skill IDs to our stored values.
  class WeaponProcessor < GridItemProcessor
    grid_item :weapon, deck_path: %w[deck pc weapons], association: :weapons

    # KEY_MAPPING maps the raw key value (as a string) to a canonical range or value.
    # For example, in our test we want a raw key "10001" to be interpreted as any key whose
    # canonical granblue_id is between 697 and 706.
    KEY_MAPPING = {
      '10001' => %w[697 698 699 700 701 702 703 704 705 706],
      '10002' => %w[707 708 709 710 711 712 713 714 715 716],
      '10003' => %w[717 718 719 720 721 722 723 724 725 726],
      '10004' => %w[727 728 729 730 731 732 733 734 735 736],
      '10005' => %w[737 738 739 740 741 742 743 744 745 746],
      '10006' => %w[747 748 749 750 751 752 753 754 755 756],
      '11001' => '758',
      '11002' => '759',
      '11003' => '760',
      '11004' => '760',
      '13001' => %w[1240 2204 2208], # α Pendulum
      '13002' => %w[1241 2205 2209], # β Pendulum
      '13003' => %w[1242 2206 2210], # γ Pendulum
      '13004' => %w[1243 2207 2211], # Δ Pendulum
      '14001' => %w[502 503 504 505 506 507 1213 1214 1215 1216 1217 1218], # Pendulum of Strength
      '14002' => %w[130 131 132 133 134 135 71 72 73 74 75 76], # Pendulum of Zeal
      '14003' => %w[1260 1261 1262 1263 1264 1265 1266 1267 1268 1269 1270 1271], # Pendulum of Strife
      '14004' => %w[1199 1200 1201 1202 1203 1204 1205 1206 1207 1208 1209 1210], # Pendulum of Prosperity
      '14005' => %w[2212 2213 2214 2215 2216 2217 2218 2219 2220 2221 2222 2223], # Pendulum of Extremity
      '14006' => %w[2224 2225 2226 2227 2228 2229 2230 2231 2232 2233 2234 2235], # Pendulum of Sagacity
      '14007' => %w[2236 2237 2238 2239 2240 2241 2242 2243 2244 2245 2246 2247], # Pendulum of Supremacy
      '14011' => %w[322 323 324 325 326 327 1310 1311 1312 1313 1314 1315], # Chain of Temperament
      '14012' => %w[764 765 766 767 768 769 1731 1732 1733 1734 1735 948], # Chain of Restoration
      '14013' => %w[1171 1172 1173 1174 1175 1176 1736 1737 1738 1739 1740 1741], # Chain of Glorification
      '14014' => '1723', # Chain of Temptation
      '14015' => '1724', # Chain of Forbiddance
      '14016' => '1725', # Chain of Depravity
      '14017' => '1726', # Chain of Falsehood
      '15001' => '1446',
      '15002' => '1447',
      '15003' => '1448', # Abyss Teluma
      '15004' => '1449', # Crag Teluma
      '15005' => '1450', # Tempest Teluma
      '15006' => '1451',
      '15007' => '1452', # Malice Teluma
      '15008' => %w[2043 2044 2045 2046 2047 2048],
      '15009' => %w[2049 2050 2051 2052 2053 2054], # Oblivion Teluma
      '16001' => %w[1228 1229 1230 1231 1232 1233], # Optimus Teluma
      '16002' => %w[1234 1235 1236 1237 1238 1239], # Omega Teluma
      '17001' => '1807',
      '17002' => '1808',
      '17003' => '1809',
      '17004' => '1810',
      # Emblems (series {24})
      '3' => '3',
      '2' => '2',
      '1' => '1',
      # Anklets (series {44} — Destroyer)
      '19001' => %w[2655 2656 2657 2658 2659 2660 2661 2662 2663 2664 2665 2666], # Anklet of Oblivion
      '19002' => %w[2667 2668 2669 2670 2671 2672 2673 2674 2675 2676 2677 2678], # Anklet of Ascendance
      '19003' => %w[2679 2680 2681 2682 2683 2684 2685 2686 2687 2688 2689 2690]  # Anklet of Maximality
    }.freeze

    AWAKENING_MAPPING = {
      '1' => 'weapon-atk',
      '2' => 'weapon-def',
      '3' => 'weapon-special',
      '4' => 'weapon-ca',
      '5' => 'weapon-skill',
      '6' => 'weapon-heal',
      '7' => 'weapon-multi'
    }.freeze

    # Game series IDs for element-changeable weapon series (Revenant, Ultima, Superlative, Class Champion)
    ELEMENT_CHANGEABLE_GAME_SERIES_IDS = [4, 13, 17, 19].freeze

    ##
    # @param party [Party] the Party record.
    # @param data [Hash] the full deck JSON.
    # @param type [Symbol] (optional) processing type.
    # @param options [Hash] additional options.
    def initialize(party, data, type = :normal, options = {})
      super
      @augment_parser = Granblue::AugmentSkillParser.new(log_tag: 'WeaponProcessor')
      @game_sync_attrs = {}.compare_by_identity
    end

    private

    AX_ATTRIBUTES = %i[ax_modifier1_id ax_strength1 ax_modifier2_id ax_strength2].freeze
    private_constant :AX_ATTRIBUTES

    def build_items
      @data['deck']['pc']['weapons'].filter_map { |key, raw_weapon| build_weapon(key.to_i, raw_weapon) }
    end

    # A weapon whose game AX data fails validation is saved without its AX
    # skills: losing the whole weapon is worse than losing its AX skills.
    def retry_save?(grid_weapon, error)
      return false unless ax_present?(grid_weapon)

      log_warn "Dropping AX skills to save GridWeapon: #{error.record.errors.full_messages.join(', ')}"
      add_warning('ax_skills_dropped', grid_weapon, grid_weapon.weapon)
      clear_ax(grid_weapon)
      true
    end

    def ax_present?(grid_weapon)
      AX_ATTRIBUTES.any? { |attr| grid_weapon[attr].present? }
    end

    def clear_ax(grid_weapon)
      AX_ATTRIBUTES.each { |attr| grid_weapon[attr] = nil }
    end

    ##
    # What the collection weapon takes from the game besides uncap, so that
    # sync_from_collection! round-trips it: keys, AX, element, awakening, and
    # befoulment, permeation, exorcism and skill levels when the game sent them.
    def game_customizations(grid_weapon)
      updates = grid_weapon.slice(:weapon_key1_id, :weapon_key2_id, :weapon_key3_id, *AX_ATTRIBUTES, :element)
                           .symbolize_keys
      updates.merge!(@game_sync_attrs.fetch(grid_weapon, {}))

      if grid_weapon.awakening_id.present?
        updates[:awakening_id] = grid_weapon.awakening_id
        updates[:awakening_level] = grid_weapon.awakening_level || 1
      end
      updates
    end

    ##
    # Builds the grid weapon for one deck slot (1 is the mainhand).
    #
    # @param slot [Integer] the deck slot.
    # @param raw_weapon [Hash] the slot's raw weapon data.
    # @return [GridWeapon, nil]
    def build_weapon(slot, raw_weapon)
      return if incomplete?(raw_weapon)

      master = raw_weapon['master']
      element_changeable = ELEMENT_CHANGEABLE_GAME_SERIES_IDS.include?(master['series_id'].to_i)
      weapon = find_weapon(master['id'], element_changeable, master['name'])
      unless weapon
        log_error "Weapon not found with id #{master['id']}"
        return
      end

      grid_weapon = new_grid_weapon(weapon, slot, raw_weapon['param'], game_element(master, element_changeable))
      apply_game_details(grid_weapon, raw_weapon)
      grid_weapon
    end

    def new_grid_weapon(weapon, slot, param, element)
      level = param['level'].to_i
      transcendence_step = level_to_transcendence(level)
      position = slot == 1 ? -1 : slot - 2

      grid_weapon = GridWeapon.new(party: @party, weapon: weapon, position: position, mainhand: position == -1,
                                   uncap_level: level_to_uncap(level, transcendence_step),
                                   transcendence_step: transcendence_step, element: element)
      link_collection_weapon(grid_weapon, param['id'], element)
      grid_weapon
    end

    # The element the game shows for an element-changeable weapon; nil for any other.
    def game_element(master, element_changeable)
      attribute = master['attribute'].to_i
      attribute if element_changeable && attribute.positive? && GranblueEnums::ELEMENTS.value?(attribute)
    end

    # Links to the collection weapon with the game's copy id, creating one when the
    # user imports to their collection. A weapon without an id isn't linked.
    def link_collection_weapon(grid_weapon, game_id, element)
      return if game_id.blank?

      link_collection(grid_weapon, { game_id: game_id.to_s },
                      weapon_id: grid_weapon.weapon_id,
                      uncap_level: grid_weapon.uncap_level,
                      transcendence_step: grid_weapon.transcendence_step,
                      element: element)
    end

    # Awakening, weapon keys and augment skills.
    def apply_game_details(grid_weapon, raw_weapon)
      arousal_data = raw_weapon.dig('param', 'arousal')
      if arousal_data && arousal_data['is_arousal_weapon']
        grid_weapon.awakening_id = map_arousal_to_awakening(arousal_data)
        grid_weapon.awakening_level = arousal_data['level'].to_i.positive? ? arousal_data['level'].to_i : 1
      end

      # The skill ids name the weapon keys
      skill_ids = [raw_weapon['skill1'], raw_weapon['skill2'], raw_weapon['skill3']].compact.pluck('id')
      process_weapon_keys(grid_weapon, skill_ids, raw_weapon) if skill_ids.length.positive?

      process_augment_skills(grid_weapon, raw_weapon['param'])
    end

    ##
    # Derives the uncap level from a weapon's current level and transcendence step.
    # Deck weapon data does not include an evolution field, so uncap must be inferred.
    #
    # @param level [Integer] the weapon's current level.
    # @param transcendence_step [Integer] the computed transcendence step.
    # @return [Integer] the uncap level (3-6).
    def level_to_uncap(level, transcendence_step)
      return 6 if transcendence_step.positive? || level > 200
      return 5 if level > 150
      return 4 if level > 100

      3
    end

    # GBF series_id to WeaponSeries slug mapping (a subset of GameDataImport::WEAPON_SERIES_SLUGS)
    GBF_WEAPON_SERIES_TO_SLUG = {
      3 => 'dark-opus', 13 => 'ultima', 17 => 'superlative',
      19 => 'class-champion', 27 => 'draconic', 40 => 'draconic-providence', 44 => 'destroyer'
    }.freeze
    private_constant :GBF_WEAPON_SERIES_TO_SLUG

    ##
    # Processes weapon key data and assigns them to the grid_weapon.
    #
    # @param grid_weapon [GridWeapon] the grid weapon record being built.
    # @param skill_ids [Array<String>] an array of key identifiers.
    # @param raw_weapon [Hash] the raw weapon data (for series_id fallback).
    # @return [void]
    def process_weapon_keys(grid_weapon, skill_ids, raw_weapon = {})
      weapon_series = grid_weapon.weapon.weapon_series

      # Fallback: if the weapon doesn't have a series, look it up from the deck's series_id
      unless weapon_series
        game_series_id = raw_weapon.dig('master', 'series_id').to_i
        slug = GBF_WEAPON_SERIES_TO_SLUG[game_series_id]
        weapon_series = WeaponSeries.find_by(slug: slug) if slug
      end

      unless weapon_series
        Rails.logger.debug { "[WEAPON] Skipping weapon keys: no weapon_series for weapon #{grid_weapon.weapon&.granblue_id}" }
        return
      end

      skill_ids.each do |skill_id|
        # Go to the next iteration unless the key under which `skill_id` exists
        mapping_pair = KEY_MAPPING.find { |_key, value| Array(value).include?(skill_id.to_s) }
        next unless mapping_pair

        # Fetch the key from the mapping_pair and find the weapon key based on the weapon series
        mapping_value = mapping_pair.first

        # Find weapon key using the weapon_series relationship
        candidate = WeaponKey.joins(:weapon_series)
                             .where(granblue_id: mapping_value, weapon_series: { id: weapon_series.id })
                             .first

        if candidate
          grid_weapon["weapon_key#{candidate.slot + 1}_id"] = candidate.id
        else
          Rails.logger.warn "[WEAPON] No matching WeaponKey found for raw key #{skill_id} (mapping #{mapping_value}, series #{weapon_series.slug})"
        end
      end
    end

    ##
    ##
    # Assigns augment skills and skill level from the game data: befoulment,
    # permeation and exorcism level for Odious weapons, AX skills otherwise.
    # The non-AX values are remembered so update_collection_from_game can push
    # them to the linked collection weapon before sync_from_collection! copies
    # the collection back. (AX is pushed from the grid weapon itself, since an
    # invalid roll is cleared before save.)
    #
    # @param grid_weapon [GridWeapon] the grid weapon record being built.
    # @param param [Hash] the raw weapon's `param` data.
    # @return [void]
    def process_augment_skills(grid_weapon, param)
      attrs = @augment_parser.attributes(param)
      grid_weapon.assign_attributes(attrs)
      @game_sync_attrs[grid_weapon] = attrs.except(*AX_ATTRIBUTES)
    end

    ##
    # Maps the in‑game awakening data (stored under "arousal") to our Awakening record.
    #
    # This method looks at the "skill" array inside the arousal data and uses the first
    # awakening’s skill_id to find the corresponding Awakening record.
    #
    # @param arousal_data [Hash] the raw arousal (awakening) data.
    # @return [String, nil] the database awakening id or nil if not found.
    def map_arousal_to_awakening(arousal_data)
      raw_data = arousal_data.with_indifferent_access

      return nil if raw_data.nil?
      return nil unless raw_data.is_a?(Hash)
      return nil unless raw_data.key?('form')

      id = raw_data['form'].to_s
      return unless AWAKENING_MAPPING.key?(id)

      slug = AWAKENING_MAPPING[id]
      awakening = Awakening.find_by(slug: slug)

      awakening&.id
    end

    # Finds a Weapon record for the given game ID.
    # For element-changeable weapons, the game sends element-variant IDs that differ
    # from the base granblue_id stored in our DB. We resolve these via element_variant_ids JSONB,
    # falling back to name matching if the JSONB data isn't populated.
    def find_weapon(weapon_id, element_changeable, weapon_name)
      # Direct match (works for non-elemental weapons and base-element variants)
      weapon = Weapon.find_by(granblue_id: weapon_id)
      return weapon if weapon

      return nil unless element_changeable

      # Primary: reverse-lookup via element_variant_ids JSONB
      weapon = Weapon.where(
        'EXISTS (SELECT 1 FROM jsonb_each_text(element_variant_ids) AS kv WHERE kv.value = ?)',
        weapon_id
      ).first
      if weapon
        Rails.logger.info "[WEAPON] Resolved element-changeable weapon (game id #{weapon_id}) via element_variant_ids on #{weapon.granblue_id}"
        return weapon
      end

      # Fallback: name match within element-changeable weapon series
      return nil unless weapon_name

      weapon = Weapon.joins(:weapon_series)
                     .where(weapon_series: { element_changeable: true })
                     .where(name_en: weapon_name)
                     .first
      if weapon
        Rails.logger.info "[WEAPON] Resolved element-changeable weapon '#{weapon_name}' (game id #{weapon_id}) " \
                          "via name fallback to #{weapon.granblue_id}"
      end
      weapon
    end
  end
end
