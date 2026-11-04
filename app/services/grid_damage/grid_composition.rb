# frozen_string_literal: true

module GridDamage
  # Counts the grid needs for per_grid_count effects and count-based conditions.
  # Count-basis names are intentionally explicit: "weapon group" in game text can
  # mean same proficiency, distinct proficiencies, or series membership.
  module GridComposition
    module_function

    # Weapon-type proficiency id → specialty name (matches Cloud-style per-specialty tables).
    PROFICIENCY_NAME = GranblueEnums::PROFICIENCY_ENUM.invert.transform_values(&:to_s).freeze
    ALL_WEAPON_TYPE_COUNT = PROFICIENCY_NAME.size

    CANONICAL_COUNT_BASES = %w[
      same_weapon_type
      max_same_weapon_type
      distinct_weapon_types
      same_series
      same_element_series
      omega_skill
      crew_races
    ].freeze

    PREFIXED_COUNT_BASIS_PATTERN = /\Aseries:[a-z0-9][a-z0-9_-]*\z/

    def valid_count_basis?(basis)
      CANONICAL_COUNT_BASES.include?(basis.to_s) || basis.to_s.match?(PREFIXED_COUNT_BASIS_PATTERN)
    end

    def valid_count_condition?(condition)
      return true unless condition.is_a?(Hash)

      type = condition['type']
      return false if %w[weapon_group_count same_weapon_type_count].include?(type)
      return true unless type == 'count_basis_gte'
      return false if condition.key?('all')

      threshold = Integer(condition['gte'], exception: false)
      valid_count_basis?(condition['basis']) && threshold&.positive?
    end

    def for_party(party)
      entries = party.weapons.includes(weapon: [:weapon_series, { weapon_skills: :weapon_skill_versions }]).filter_map do |gw|
        entry_for(gw)
      end
      mc_specialties = mc_specialties_for(party)
      summarize(entries).merge(
        mc_specialty: mc_specialties.first, mc_specialties: mc_specialties,
        # crew races incl. the MC (Gran/Djeeta are Human) — bahamut count basis
        character_races: [1] + party.characters.filter_map { |gc| gc.character&.race1&.to_i }
      )
    end

    # One grid weapon's entry for summarize, or nil for an empty slot.
    def entry_for(grid_weapon)
      w = grid_weapon.weapon
      return unless w

      modifiers = []
      omega = false
      w.weapon_skills.each do |ws|
        v = ws.active_version(uncap_level: grid_weapon.uncap_level.to_i, transcendence_step: grid_weapon.transcendence_step.to_i)
        next unless v

        # omega-skill counters (Vivification) go by the RESOLVED frame — a Dark Opus
        # Renunciation's s1 counts as an omega skill despite its template series
        # (mcwZet: Vivification counts 7, incl. the opus).
        omega ||= FrameResolver.frame_for(w, v) == 'omega'
        next unless v.resolved_modifier

        modifiers << v.resolved_modifier
      end
      {
        proficiency: w.proficiency,
        series_slug: w.weapon_series&.slug,
        granblue_id: w.granblue_id,
        modifiers: modifiers,
        omega: omega,
        element: ElementScope.element_of(grid_weapon)
      }
    end

    # The MC's weapon specialties (BOTH job proficiencies) — select the row of
    # per-specialty skills (e.g. Cloud of Howling Twilight). A job matching on either
    # proficiency gets the specialty tier (dAV5ds: Lancer Origin is spear+axe; the
    # panel shows Pillar-Smasher's Conviction at the axe values).
    # A party without a job still implies one specialty: the mainhand weapon's type
    # is always among the wielding job's proficiencies (HoEE8b: axe MH resolves
    # Pillar-Smasher's Conviction at the axe tier even with no job saved).
    def mc_specialties_for(party)
      job = party.try(:job)
      mc_specialties = [job&.proficiency1, job&.proficiency2].filter_map { |p| PROFICIENCY_NAME[p] }
      return mc_specialties unless mc_specialties.empty?

      mh = party.weapons.find(&:mainhand)&.weapon
      [PROFICIENCY_NAME[mh&.proficiency]].compact
    end

    # Pure: entries = [{ proficiency:, series_slug:, granblue_id:, modifiers: [..], omega: bool,
    #                   element: "fire" | nil }, …]
    def summarize(entries)
      types = Hash.new(0)
      series = Hash.new(0)
      series_by_element = Hash.new(0)
      ids = Hash.new(0)
      modifiers = Set.new
      omega = 0
      omega_by_element = Hash.new(0)
      entries.each do |e|
        types[e[:proficiency]] += 1
        series[e[:series_slug]] += 1 if e[:series_slug].present?
        series_by_element[[e[:series_slug], e[:element]]] += 1 if e[:series_slug].present? && e[:element]
        ids[e[:granblue_id]] += 1
        e[:modifiers].each { |m| modifiers << m }
        omega += 1 if e[:omega]
        omega_by_element[e[:element]] += 1 if e[:omega] && e[:element]
      end
      {
        weapon_type_counts: types,
        weapon_series_counts: series,
        weapon_series_counts_by_element: series_by_element,
        id_counts: ids,
        distinct_weapon_type_count: types.size,
        max_weapon_type_count: types.values.max.to_i,
        skill_type_count: modifiers.size,
        omega_skill_count: omega,
        omega_skill_counts_by_element: omega_by_element
      }
    end

    def count_for_basis(basis, weapon:, composition:, effect: nil)
      raise ArgumentError, "Unknown count_basis: #{basis.inspect}" unless valid_count_basis?(basis)

      case basis
      when 'same_weapon_type', 'max_same_weapon_type', 'distinct_weapon_types'
        weapon_type_count(basis, weapon: weapon, composition: composition)
      when 'omega_skill' then omega_skill_count(weapon: weapon, composition: composition)
      when 'crew_races' then crew_race_count(effect: effect, composition: composition)
      else series_count(basis, weapon: weapon, composition: composition)
      end
    end

    # Counts by weapon type: the bearing weapon's own, the most common, or how many differ.
    def weapon_type_count(basis, weapon:, composition:)
      case basis
      when 'same_weapon_type' then composition.dig(:weapon_type_counts, weapon&.proficiency).to_i
      when 'max_same_weapon_type' then composition[:max_weapon_type_count].to_i
      when 'distinct_weapon_types' then composition[:distinct_weapon_type_count].to_i
      end
    end

    # Counts by series: the bearing weapon's own, its own in its element, or a named one.
    def series_count(basis, weapon:, composition:)
      case basis
      when 'same_series'
        composition.dig(:weapon_series_counts, weapon&.weapon_series&.slug).to_i
      # Vitiation and Guile count "weapons with Taboo Allowater's skills": its series in its
      # own element (a Fire Odious weapon doesn't count for Water's)
      when 'same_element_series'
        element = Calculator::ELEMENT_WORD[weapon&.element.to_i]
        composition.dig(:weapon_series_counts_by_element, [weapon&.weapon_series&.slug, element]).to_i
      else
        composition.dig(:weapon_series_counts, basis.split(':', 2).last).to_i
      end
    end

    # Vivification counts weapons with its own element's omega skills ("Ironflame's"
    # for Iron's): 6C5bN9's Earth Lifetree's Insignia don't count on a Fire grid.
    def omega_skill_count(weapon:, composition:)
      element = Calculator::ELEMENT_WORD[weapon&.element.to_i]
      by_element = composition[:omega_skill_counts_by_element]
      element && by_element ? by_element[element].to_i : composition[:omega_skill_count].to_i
    end

    def crew_race_count(effect:, composition:)
      races = Array(effect&.condition&.dig('races')).map(&:to_i)
      composition.fetch(:character_races, []).count { |r| races.include?(r.to_i) }
    end
  end
end
