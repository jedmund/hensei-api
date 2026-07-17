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

      # Identity-framed series come BEFORE the version's own series: their skills are
      # injected from a shared series template whose skill_series is an import default,
      # not a frame claim (dAV5ds: Scythe of Renunciation's Apotheosis lands on the Ω
      # panel lines despite skill_series "normal").
      identity = identity_frame(weapon)
      return identity if identity

      version.resolved_series.presence || "normal"
    end

    def identity_frame(weapon)
      case weapon.weapon_series&.slug
      when "dark-opus"
        weapon.name_en.to_s.include?("Renunciation") ? "omega" : "normal"
      when "draconic", "draconic-providence"
        "ex"
      end
    end
  end
end
