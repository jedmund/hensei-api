# frozen_string_literal: true

module GridDamage
  # Which grid weapons' skills reach the panel's viewer, the MC. A weapon skill that
  # names an element ("Big boost to earth allies' ATK", "{{WeaponElement}} allies",
  # "dark MC's max HP") boosts only allies of that element, so an Earth weapon's
  # Majesty does nothing for a Fire MC. Skills that name no element affect allies of
  # any element (gbf.wiki/Dark_Opus_Weapons; Voltage II, Wrath, Vivification and
  # Celestial skills carry "Affects allies of any element" notes), as do Bahamut's
  # race-based and Twinpain's "all allies" skills.
  module ElementScope
    module_function

    ELEMENT_WORDS = %w[fire water earth wind light dark].freeze
    SCOPED_TARGET = /
      (?:\b(#{ELEMENT_WORDS.join('|')})|\{\{WeaponElement[^}]*\}\})
      \s+(?:allies|ally|allied|MC)\b
    /ix

    # Exalto boosts name skill families ("20% boost to Lifetree's weapon skills"),
    # which belong to one element, so they scope like an element-named skill.
    ELEMENT_BOUND_BOOSTS = %w[optimus_exalto omega_exalto odious_exalto].freeze

    # A skill's demerit falls on the same allies as its boost: "土属性キャラの攻撃力上昇(大)/
    # 毎ターンダメージを受ける" carries the Earth subject into the turn damage, and a Fire
    # MC's panel shows no Turn DMG for three Earth Lifetree's Insignia (6C5bN9).

    # Weapon awakenings that boost only allies of the weapon's element
    # (gbf.wiki/Weapon_Awakening: "Weapon Awakening in this series only affect allies
    # of the same element as the weapon.").
    ELEMENT_BOUND_AWAKENING_SERIES = %w[revans].freeze

    # The MC's element: the main weapon's. A party without one falls back to the most
    # common element in the grid.
    def panel_element(party)
      weapons = party.weapons.to_a
      mainhand = weapons.find(&:mainhand)
      element_of(mainhand) || weapons.filter_map { |gw| element_of(gw) }
                                     .group_by(&:itself).max_by { |_, v| v.size }&.first
    end

    # A grid weapon's element word: the copy's own element (Ultima, Dark Opus and other
    # element-changeable weapons) or the catalogue's. nil when neither is set.
    def element_of(grid_weapon)
      return nil unless grid_weapon

      own = grid_weapon.element.to_i
      Calculator::ELEMENT_WORD[own.positive? ? own : grid_weapon.weapon&.element.to_i]
    end

    # Whether a skill version names the element it boosts.
    def scoped_skill?(version)
      version.try(:description_en).to_s.match?(SCOPED_TARGET)
    end

    # The elements a skill's text names outright ("Big boost to water allies' ATK").
    def named_elements(version)
      version.try(:description_en).to_s.scan(SCOPED_TARGET).flatten.compact.map(&:downcase).uniq
    end

    # Whether one boost of a skill reaches an MC of panel_element.
    def applies?(version:, boost_type:, grid_weapon:, panel_element:)
      return true if panel_element.nil?
      return true unless ELEMENT_BOUND_BOOSTS.include?(boost_type) || scoped_skill?(version)

      # Early gacha weapons carry skills for another element than their own (Ascalon's
      # Hoarfrost's Might boosts water allies), so a named element wins. An element-
      # changeable copy (Revenant "Element Changed", Ultima) follows its own element:
      # its text names the template's default element.
      named = named_elements(version)
      return named.include?(panel_element) if named.any? && !element_changeable?(grid_weapon)

      weapon_element = element_of(grid_weapon)
      weapon_element.nil? || weapon_element == panel_element
    end

    def element_changeable?(grid_weapon)
      catalogue = grid_weapon.weapon&.element.to_i
      own = grid_weapon.element.to_i
      catalogue.zero? || (own.positive? && own != catalogue)
    end

    def awakening_applies?(grid_weapon:, panel_element:)
      return true if panel_element.nil?
      return true unless ELEMENT_BOUND_AWAKENING_SERIES.include?(grid_weapon.weapon&.weapon_series&.slug)

      weapon_element = element_of(grid_weapon)
      weapon_element.nil? || weapon_element == panel_element
    end
  end
end
