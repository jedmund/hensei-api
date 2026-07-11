# frozen_string_literal: true

module GridDamage
  # Counts the grid needs for per_grid_count effects and count-based conditions.
  # Count-basis names are intentionally explicit: "weapon group" in game text can
  # mean same proficiency, distinct proficiencies, series membership, or a named group.
  module GridComposition
    module_function

    # Weapon-type proficiency id → specialty name (matches Cloud-style per-specialty tables).
    PROFICIENCY_NAME = { 1 => "sabre", 2 => "dagger", 3 => "axe", 4 => "spear", 5 => "bow",
                         6 => "staff", 7 => "melee", 8 => "harp", 9 => "gun", 10 => "katana" }.freeze

    CANONICAL_COUNT_BASES = %w[
      same_weapon_type
      max_same_weapon_type
      distinct_weapon_types
      same_series
      omega_skill
      crew_races
    ].freeze

    PREFIXED_COUNT_BASIS_PATTERN = /\A(?:series|group):[a-z0-9][a-z0-9_-]*\z/.freeze

    def valid_count_basis?(basis)
      CANONICAL_COUNT_BASES.include?(basis.to_s) || basis.to_s.match?(PREFIXED_COUNT_BASIS_PATTERN)
    end

    def for_party(party)
      entries = party.weapons.includes(weapon: [:weapon_series, :weapon_count_groups, { weapon_skills: :weapon_skill_versions }]).filter_map do |gw|
        w = gw.weapon
        next unless w

        modifiers = []
        omega = false
        w.weapon_skills.each do |ws|
          v = ws.active_version(uncap_level: gw.uncap_level.to_i, transcendence_step: gw.transcendence_step.to_i)
          next unless v

          # omega-skill counters (Vivification) go by the RESOLVED frame — a Dark Opus
          # Renunciation's s1 counts as an omega skill despite its template series
          # (mcwZet: Vivification counts 7, incl. the opus).
          omega ||= FrameResolver.frame_for(w, v) == "omega"
          next unless v.resolved_modifier

          modifiers << v.resolved_modifier
        end
        {
          proficiency: w.proficiency,
          series_slug: w.weapon_series&.slug,
          group_slugs: w.weapon_count_groups.map(&:slug),
          granblue_id: w.granblue_id,
          modifiers: modifiers,
          omega: omega
        }
      end
      # The MC's weapon specialties (BOTH job proficiencies) — select the row of
      # per-specialty skills (e.g. Cloud of Howling Twilight). A job matching on either
      # proficiency gets the specialty tier (dAV5ds: Lancer Origin is spear+axe; the
      # panel shows Pillar-Smasher's Conviction at the axe values).
      # A party without a job still implies one specialty: the mainhand weapon's type
      # is always among the wielding job's proficiencies (HoEE8b: axe MH resolves
      # Pillar-Smasher's Conviction at the axe tier even with no job saved).
      job = party.try(:job)
      mc_specialties = [job&.proficiency1, job&.proficiency2].filter_map { |p| PROFICIENCY_NAME[p] }
      if mc_specialties.empty?
        mh = party.weapons.find { |gw| gw.mainhand }&.weapon
        mc_specialties = [PROFICIENCY_NAME[mh&.proficiency]].compact
      end
      summarize(entries).merge(
        mc_specialty: mc_specialties.first, mc_specialties: mc_specialties,
        # crew races incl. the MC (Gran/Djeeta are Human) — bahamut count basis
        character_races: [1] + party.characters.filter_map { |gc| gc.character&.race1&.to_i }
      )
    end

    # Pure: entries = [{ proficiency:, series_slug:, group_slugs:, granblue_id:, modifiers: [..], omega: bool }, …]
    def summarize(entries)
      types = Hash.new(0)
      series = Hash.new(0)
      groups = Hash.new(0)
      ids = Hash.new(0)
      modifiers = Set.new
      omega = 0
      entries.each do |e|
        types[e[:proficiency]] += 1
        series[e[:series_slug]] += 1 if e[:series_slug].present?
        Array(e[:group_slugs]).each { |slug| groups[slug] += 1 if slug.present? }
        ids[e[:granblue_id]] += 1
        e[:modifiers].each { |m| modifiers << m }
        omega += 1 if e[:omega]
      end
      {
        weapon_type_counts: types,
        weapon_series_counts: series,
        weapon_count_group_counts: groups,
        id_counts: ids,
        distinct_weapon_type_count: types.size,
        max_weapon_type_count: types.values.max.to_i,
        skill_type_count: modifiers.size,
        omega_skill_count: omega
      }
    end

    def count_for_basis(basis, weapon:, composition:, effect: nil)
      raise ArgumentError, "Unknown count_basis: #{basis.inspect}" unless valid_count_basis?(basis)

      case basis
      when "same_weapon_type"
        composition.dig(:weapon_type_counts, weapon&.proficiency).to_i
      when "max_same_weapon_type"
        composition[:max_weapon_type_count].to_i
      when "distinct_weapon_types"
        composition[:distinct_weapon_type_count].to_i
      when "same_series"
        composition.dig(:weapon_series_counts, weapon&.weapon_series&.slug).to_i
      when "omega_skill"
        composition[:omega_skill_count].to_i
      when "crew_races"
        races = Array(effect&.condition&.dig("races")).map(&:to_i)
        composition.fetch(:character_races, []).count { |r| races.include?(r.to_i) }
      else
        prefixed_count(basis, composition)
      end
    end

    def prefixed_count(basis, composition)
      prefix, slug = basis.split(":", 2)
      case prefix
      when "series" then composition.dig(:weapon_series_counts, slug).to_i
      when "group" then composition.dig(:weapon_count_group_counts, slug).to_i
      end
    end

    private_class_method :prefixed_count
  end
end
