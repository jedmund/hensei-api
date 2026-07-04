# frozen_string_literal: true

module GridDamage
  # Counts the grid needs for per_grid_count effects and count-based conditions:
  # distinct weapon types/groups, per-id copies, distinct skill types, omega-skill count.
  #
  # NOTE: count bases that need weapon-GROUP tags we don't store cleanly (`epic`,
  # `militis`) aren't computed here — a documented data gap; `weapon_group` is approximated
  # by weapon TYPE (proficiency).
  module GridComposition
    module_function

    # Weapon-type proficiency id → specialty name (matches Cloud-style per-specialty tables).
    PROFICIENCY_NAME = { 1 => "sabre", 2 => "dagger", 3 => "axe", 4 => "spear", 5 => "bow",
                         6 => "staff", 7 => "melee", 8 => "harp", 9 => "gun", 10 => "katana" }.freeze

    def for_party(party)
      entries = party.weapons.includes(weapon: { weapon_skills: :weapon_skill_versions }).filter_map do |gw|
        w = gw.weapon
        next unless w

        modifiers = []
        omega = false
        w.weapon_skills.each do |ws|
          v = ws.active_version(uncap_level: gw.uncap_level.to_i, transcendence_step: gw.transcendence_step.to_i)
          next unless v && v.skill_modifier

          modifiers << v.skill_modifier
          omega ||= v.skill_series == "omega"
        end
        { proficiency: w.proficiency, granblue_id: w.granblue_id, modifiers: modifiers, omega: omega }
      end
      # The MC's weapon specialties (BOTH job proficiencies) — select the row of
      # per-specialty skills (e.g. Cloud of Howling Twilight). A job matching on either
      # proficiency gets the specialty tier (dAV5ds: Lancer Origin is spear+axe; the
      # panel shows Pillar-Smasher's Conviction at the axe values).
      job = party.try(:job)
      mc_specialties = [job&.proficiency1, job&.proficiency2].filter_map { |p| PROFICIENCY_NAME[p] }
      summarize(entries).merge(mc_specialty: mc_specialties.first, mc_specialties: mc_specialties)
    end

    # Pure: entries = [{ proficiency:, granblue_id:, modifiers: [..], omega: bool }, …]
    def summarize(entries)
      types = Hash.new(0)
      ids = Hash.new(0)
      modifiers = Set.new
      omega = 0
      entries.each do |e|
        types[e[:proficiency]] += 1
        ids[e[:granblue_id]] += 1
        e[:modifiers].each { |m| modifiers << m }
        omega += 1 if e[:omega]
      end
      {
        weapon_type_counts: types,
        id_counts: ids,
        weapon_group_count: types.size,
        skill_type_count: modifiers.size,
        omega_skill_count: omega
      }
    end
  end
end
