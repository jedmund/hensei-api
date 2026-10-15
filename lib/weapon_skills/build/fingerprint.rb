# frozen_string_literal: true

module WeaponSkills
  module Build
    # What a weapon's build was made from, as one SHA256: the weapon's own stored sources
    # (wiki_raw, expanded, transclusion), every family template (shared by all weapons, so
    # any template change makes every weapon stale), the weapon's overlay entries and
    # Build::VERSION. Stored on weapons.weapon_skill_build_fingerprint after a write; a
    # build without all=true skips weapons whose fingerprint still matches.
    #
    # Only sha256 values and canonical JSON go in, so the result doesn't depend on row
    # order, ids or fetch times.
    class Fingerprint
      WEAPON_KINDS = %w[wiki_raw expanded transclusion].freeze
      SECTIONS = Granblue::CurationSnapshot::Overlay::SECTIONS

      def self.for(weapon, context:)
        new(context).for(weapon)
      end

      # One instance per run: the shared parts are computed once.
      def initialize(context)
        @context = context
      end

      def for(weapon)
        parts = ["version:#{VERSION}", "templates:#{templates_digest}"]
        parts += sources_for(weapon).map { |kind, key, sha| "source:#{kind}:#{key}:#{sha}" }
        parts += overlay_entries_for(weapon.granblue_id)
        Digest::SHA256.hexdigest(parts.join("\n"))
      end

      # Loads every weapon's source digests in one query, for a run over many weapons.
      def preload_sources!
        @sources_by_weapon = WeaponSource.where(kind: WEAPON_KINDS).where.not(weapon_id: nil)
                                         .pluck(:weapon_id, :kind, :key, :sha256)
                                         .group_by(&:first)
                                         .transform_values { |rows| rows.map { |r| r.drop(1) }.sort }
        self
      end

      private

      def sources_for(weapon)
        if @sources_by_weapon
          @sources_by_weapon.fetch(weapon.id, [])
        else
          WeaponSource.where(weapon_id: weapon.id, kind: WEAPON_KINDS).pluck(:kind, :key, :sha256).sort
        end
      end

      def templates_digest
        @templates_digest ||= Digest::SHA256.hexdigest(
          WeaponSource.where(kind: "family_template").pluck(:key, :sha256).sort.map { |k, s| "#{k}:#{s}" }.join("\n")
        )
      end

      def overlay_entries_for(granblue_id)
        overlay_index.fetch(granblue_id.to_s, [])
      end

      # granblue_id → its overlay entries as sorted canonical JSON lines.
      def overlay_index
        @overlay_index ||= begin
          pairs = SECTIONS.flat_map do |section|
            @context.overlay.entries(section).filter_map do |entry|
              [entry["weapon"].to_s, "#{section}:#{JSON.generate(canonical(entry))}"] if entry["weapon"].present?
            end
          end
          pairs.group_by(&:first).transform_values { |group| group.map(&:last).sort }
        end
      end

      def canonical(value)
        case value
        when Hash then value.sort_by { |k, _| k.to_s }.to_h { |k, v| [k.to_s, canonical(v)] }
        when Array then value.map { |v| canonical(v) }
        else value
        end
      end
    end
  end
end
