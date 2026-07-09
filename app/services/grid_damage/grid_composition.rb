# frozen_string_literal: true

module GridDamage
  # Counts the grid needs for per_grid_count effects and count-based conditions:
  # weapon-type/proficiency copies, weapon-series copies, per-id copies, distinct
  # skill types, omega-skill count, and max same-type count.
  module GridComposition
    module_function

    # Weapon-type proficiency id → specialty name (matches Cloud-style per-specialty tables).
    PROFICIENCY_NAME = { 1 => "sabre", 2 => "dagger", 3 => "axe", 4 => "spear", 5 => "bow",
                         6 => "staff", 7 => "melee", 8 => "harp", 9 => "gun", 10 => "katana" }.freeze

    def for_party(party)
      entries = party.weapons.includes(weapon: [:weapon_series, { weapon_skills: :weapon_skill_versions }]).filter_map do |gw|
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

    # Pure: entries = [{ proficiency:, series_slug:, granblue_id:, modifiers: [..], omega: bool }, …]
    def summarize(entries)
      types = Hash.new(0)
      series = Hash.new(0)
      ids = Hash.new(0)
      modifiers = Set.new
      omega = 0
      entries.each do |e|
        types[e[:proficiency]] += 1
        series[e[:series_slug]] += 1 if e[:series_slug].present?
        ids[e[:granblue_id]] += 1
        e[:modifiers].each { |m| modifiers << m }
        omega += 1 if e[:omega]
      end
      {
        weapon_type_counts: types,
        weapon_series_counts: series,
        id_counts: ids,
        weapon_group_count: types.size,
        max_weapon_type_count: types.values.max.to_i,
        skill_type_count: modifiers.size,
        omega_skill_count: omega
      }
    end
  end
end
