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
  class WeaponProcessor < BaseProcessor
    TRANSCENDENCE_LEVELS = [200, 210, 220, 230, 240, 250].freeze

    # Mapping from in‑game AX skill IDs (as strings) to our internal modifier values.
    AX_MAPPING = {
      '1588' => 2,
      '1589' => 0,
      '1590' => 1,
      '1591' => 3,
      '1592' => 4,
      '1593' => 9,
      '1594' => 13,
      '1595' => 10,
      '1596' => 5,
      '1597' => 6,
      '1599' => 8,
      '1600' => 12,
      '1601' => 11,
      '1719' => 15,
      '1720' => 16,
      '1721' => 17,
      '1722' => 14
    }.freeze

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
      '1' => '1'
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

    ELEMENTAL_WEAPON_MAPPING = %w[1040914600 1040810100 1040506800 1040312000 1040513800 1040810900 1040910300
                                  1040114200 1040027000 1040807600 1040120300 1040318500 1040710000 1040608100
                                  1040812100 1040307200 1040410200 1040510600 1040018100 1040113400 1040017300
                                  1040011900 1040412200 1040508000 1040512600 1040609100 1040411600 1040208800
                                  1040906900 1040909300 1040509700 1040014400 1040308400 1040613100 1040013200
                                  1040011300 1040413400 1040607500 1040504400 1040703600 1040406000 1040601700
                                  1040904300 1040109700 1040900300 1040002000 1040807200 1040102900 1040203000
                                  1040402800 1040507400 1040200900 1040307800 1040501600 1040706900 1040604200
                                  1040103000 1040003500 1040300100 1040907500 1040105500 1040106600 1040503500
                                  1040801300 1040410800 1040702700 1040006200 1040302300 1040803700 1040900400
                                  1040406900 1040109100 1040111600 1040706300 1040806400 1040209700 1040707500
                                  1040208200 1040214000 1040021100 1040417200 1040012600 1040317500 1040402900].freeze
    ELEMENTAL_WEAPON_MAPPING_INT = ELEMENTAL_WEAPON_MAPPING.map(&:to_i).sort.freeze

    ELEMENT_MAPPING = {
      0 => nil,
      1 => 4, # Wind -> Earth
      2 => 2, # Fire -> Fire
      3 => 3, # Water -> Water
      4 => 1, # Earth -> Wind
      5 => 6, # Dark -> Light
      6 => 5 # Light -> Dark
    }.freeze
    ##
    # Initializes a new WeaponProcessor.
    #
    # @param party [Party] the Party record.
    # @param data [Hash] the full deck JSON.
    # @param type [Symbol] (optional) processing type.
    # @param options [Hash] additional options.
    def initialize(party, data, type = :normal, options = {})
      super(party, data, options)
      @party = party
      @data = data
    end

    ##
    # Processes the deck’s weapon data and creates GridWeapon records.
    #
    # It expects the incoming data to be a Hash that contains:
    #   "deck" → "pc" → "weapons"
    #
    # @return [void]
    def process
      unless @data.is_a?(Hash)
        Rails.logger.error "[WEAPON] Invalid data format: expected a Hash, got #{@data.class}"
        return
      end

      unless @data.key?('deck') && @data['deck'].key?('pc') && @data['deck']['pc'].key?('weapons')
        Rails.logger.error '[WEAPON] Missing weapons data in deck JSON'
        return
      end

      @data = @data.with_indifferent_access
      weapons_data = @data['deck']['pc']['weapons']

      grid_weapons = process_weapons(weapons_data)

      grid_weapons.each do |grid_weapon|
        begin
          grid_weapon.save!
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[WEAPON] Failed to create GridWeapon: #{e.record.errors.full_messages.join(', ')}"
        end
      end
    end

    private

    ##
    # Processes a hash of raw weapon data and returns an array of GridWeapon records.
    #
    # @param weapons_data [Hash] the raw weapons data (keyed by slot number).
    # @return [Array<GridWeapon>]
    def process_weapons(weapons_data)
      weapons_data.map do |key, raw_weapon|
        next if raw_weapon.nil? || raw_weapon['param'].nil? || raw_weapon['master'].nil?

        position = key.to_i == 1 ? -1 : key.to_i - 2
        mainhand = (position == -1)

        uncap_level = raw_weapon.dig('param', 'uncap').to_i
        level = raw_weapon.dig('param', 'level').to_i
        transcendence_step = level_to_transcendence(level)
        series = raw_weapon.dig('master', 'series_id')
        weapon_id = raw_weapon.dig('master', 'id')

        processed_weapon_id = if Weapon.element_changeable?(series)
                                process_elemental_weapon(weapon_id)
                              else
                                weapon_id
                              end

        processed_element = if Weapon.element_changeable?(series)
                              ELEMENT_MAPPING[raw_weapon.dig('master', 'attribute')]
                            end

        weapon = Weapon.find_by(granblue_id: processed_weapon_id)

        unless weapon
          Rails.logger.error "[WEAPON] Weapon not found with id #{processed_weapon_id}"
          next
        end

        grid_weapon = GridWeapon.new(
          party: @party,
          weapon: weapon,
          position: position,
          mainhand: mainhand,
          uncap_level: uncap_level,
          transcendence_step: transcendence_step,
          element: processed_element
        )

        arousal_data = raw_weapon.dig('param', 'arousal')
        if arousal_data && arousal_data['is_arousal_weapon']
          grid_weapon.awakening_id = map_arousal_to_awakening(arousal_data)
          grid_weapon.awakening_level = arousal_data['level'].to_i.positive? ? arousal_data['level'].to_i : 1
        end

        # Extract skill IDs and convert into weapon keys
        skill_ids = [raw_weapon['skill1'], raw_weapon['skill2'], raw_weapon['skill3']].compact.map { |s| s['id'] }
        process_weapon_keys(grid_weapon, skill_ids) if skill_ids.length.positive?

        if raw_weapon.dig('param', 'augment_skill_info').present?
          process_weapon_ax(grid_weapon, raw_weapon.dig('param', 'augment_skill_info'))
        end

        grid_weapon
      end.compact
    end

    ##
    # Converts a given weapon level to a transcendence step.
    #
    # If the level is less than 200, returns 0; otherwise, floors the level
    # to the nearest 10 and returns its index in TRANSCENDENCE_LEVELS.
    #
    # @param level [Integer] the weapon’s level.
    # @return [Integer] the transcendence step.
    def level_to_transcendence(level)
      return 0 if level < 200

      floored_level = (level / 10).floor * 10
      TRANSCENDENCE_LEVELS.index(floored_level) || 0
    end

    ##
    # Processes weapon key data and assigns them to the grid_weapon.
    #
    # @param grid_weapon [GridWeapon] the grid weapon record being built.
    # @param skill_ids [Array<String>] an array of key identifiers.
    # @return [void]
    def process_weapon_keys(grid_weapon, skill_ids)
      series = grid_weapon.weapon.series.to_i

      skill_ids.each_with_index do |skill_id, idx|
        # Go to the next iteration unless the key under which `skill_id` exists
        mapping_pair = KEY_MAPPING.find { |key, value| Array(value).include?(skill_id) }
        next unless mapping_pair

        # Fetch the key from the mapping_pair and find the weapon key based on the weapon series
        mapping_value = mapping_pair.first
        candidate = WeaponKey.where('granblue_id = ? AND ? = ANY(series)', mapping_value, series).first

        if candidate
          grid_weapon["weapon_key#{idx + 1}_id"] = candidate.id
        else
          Rails.logger.warn "[WEAPON] No matching WeaponKey found for raw key #{skill_id} using mapping #{mapping_value}"
        end
      end
    end

    ##
    # Returns true if the candidate key (a string) matches the mapping entry.
    #
    # If mapping_entry includes a dash, it is interpreted as a range (e.g. "697-706").
    # Otherwise, it must match exactly.
    #
    # @param candidate_key [String] the candidate WeaponKey.granblue_id.
    # @param mapping_entry [String] the mapping entry.
    # @return [Boolean]
    def matches_key?(candidate_key, mapping_entry)
      if mapping_entry.include?('-')
        left, right = mapping_entry.split('-').map(&:to_i)
        candidate_key.to_i >= left && candidate_key.to_i <= right
      else
        candidate_key == mapping_entry
      end
    end

    ##
    # Processes AX (augment) skill data.
    #
    # The deck stores AX skills in an array of arrays under "augment_skill_info".
    # This method flattens the data and assigns each skill’s modifier and strength.
    #
    # @param grid_weapon [GridWeapon] the grid weapon record being built.
    # @param ax_skill_info [Array] the raw AX skill info.
    # @return [void]
    def process_weapon_ax(grid_weapon, ax_skill_info)
      # Flatten the nested array structure.
      ax_skills = ax_skill_info.flatten
      ax_skills.each_with_index do |ax, idx|
        ax_id = ax['skill_id'].to_s
        ax_mod = AX_MAPPING[ax_id] || ax_id.to_i
        strength = ax['effect_value'].to_s.gsub(/[+%]/, '').to_i
        grid_weapon["ax_modifier#{idx + 1}"] = ax_mod
        grid_weapon["ax_strength#{idx + 1}"] = strength
      end
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
      return nil unless raw_data.has_key?('form')

      id = (raw_data['form']).to_s
      return unless AWAKENING_MAPPING.key?(id)

      slug = AWAKENING_MAPPING[id]
      awakening = Awakening.find_by(slug: slug)

      awakening&.id
    end

    def process_elemental_weapon(granblue_id)
      granblue_int = granblue_id.to_i

      # Find the index of the first element that is >= granblue_int.
      idx = ELEMENTAL_WEAPON_MAPPING_INT.bsearch_index { |x| x >= granblue_int }

      # We'll check the candidate at idx and the one immediately before it.
      candidates = []
      if idx
        candidate = ELEMENTAL_WEAPON_MAPPING_INT[idx]
        candidates << candidate if (granblue_int - candidate).abs <= 500
        # Check the candidate just before, if it exists.
        if idx > 0
          candidate_prev = ELEMENTAL_WEAPON_MAPPING_INT[idx - 1]
          candidates << candidate_prev if (granblue_int - candidate_prev).abs <= 500
        end
      else
        # If idx is nil, then granblue_int is greater than all mapped values.
        candidate = ELEMENTAL_WEAPON_MAPPING_INT.last
        candidates << candidate if (granblue_int - candidate).abs <= 500
      end

      # If no candidate is close enough, return the original input.
      return granblue_id if candidates.empty?

      # Choose the candidate with the smallest difference.
      best_match = candidates.min_by { |x| (granblue_int - x).abs }
      best_match.to_s
    end
  end
end
