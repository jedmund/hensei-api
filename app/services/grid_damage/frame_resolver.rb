# frozen_string_literal: true

module GridDamage
  # Determines which damage frame (normal/omega/ex) a weapon's skill belongs to.
  #
  # Most skills carry the frame in their name's aura-word (Inferno's→normal,
  # Ironflame's→omega, Scarlet's→ex), captured as the version's skill_series. Aura-word-less
  # special weapons need their frame from the weapon's identity:
  #   - Dark Opus: fixed by name — "Renunciation" = Omega, "Repudiation" = Normal/Primal
  #     ("elemental icon skills are the same category as the first skill").
  #   - Draconic / Draconic Providence base Progression: EX (no Primal/Omega aura).
  # Key-determined skills (pendulum/teluma/anklet) get their frame from KeySkills, not here.
  module FrameResolver
    module_function

    def frame_for(weapon, version)
      # The wiki "Multiplier:" annotation (captured at expansion) is authoritative when present.
      authoritative = version.try(:multiplier_frame).presence
      return authoritative if authoritative

      explicit = version.skill_series.presence
      return explicit if explicit

      case weapon.weapon_series&.slug
      when "dark-opus"
        weapon.name_en.to_s.include?("Renunciation") ? "omega" : "normal"
      when "draconic", "draconic-providence"
        "ex"
      else
        "normal"
      end
    end
  end
end
