# frozen_string_literal: true

module Granblue
  class CurationSnapshot
    # The committed curation overlay as one merged document
    # (docs/weapon-skill-pipeline/overlay-v2.md).
    #
    # Reads every data/weapon_skill_curation/*.json file, plus the v1
    # data/weapon_skill_curation.json while it still exists. Every file is
    # validated before anything is returned, so a bad file aborts a sync before it
    # writes. pending/ fragments aren't read: granblue:split_weapon_skill_curation
    # folds them into the series files.
    class Overlay
      SECTIONS = %w[versions effects data ops].freeze
      OP_ORDER = %w[remove_version add_version gate description].freeze
      CANONICAL_FILE = "_canonical.json"
      NO_SERIES_FILE = "_none.json"

      class Invalid < StandardError; end

      attr_reader :files

      # files: [[label, document]], in a stable order.
      def initialize(files)
        @files = files
      end

      def self.load(dir:, legacy_path: nil)
        files = Dir.glob(File.join(dir.to_s, "*.json")).map { |path| [label(path), read(path)] }
        files << [label(legacy_path), from_v1(read(legacy_path))] if legacy_path && File.exist?(legacy_path)
        new(files).validate!
      end

      # Folds fragments (pending/) into sections. A fragment with the identity of an
      # existing entry replaces it when its stamp is newer; an identical one is dropped.
      # Changes sections in place. → the conflicts: same identity, different values,
      # as [{ "kept" => entry, "dropped" => entry }]
      def self.fold(sections, fragments)
        SECTIONS.flat_map do |section|
          entries = (sections[section] ||= [])
          at = entries.each_with_index.to_h { |entry, i| [identity(section, entry), i] }
          Array(fragments[section]).filter_map do |entry|
            key = identity(section, entry)
            i = at[key]
            if i.nil?
              at[key] = entries.size
              entries << entry
              next
            end

            current = entries[i]
            next if entry.except("edited_at", "reason") == current.except("edited_at", "reason")

            entries[i] = entry if Time.iso8601(entry["edited_at"]) > Time.iso8601(current["edited_at"])
            { "kept" => entries[i], "dropped" => entries[i].equal?(entry) ? current : entry }
          end
        end
      end

      def self.read(path)
        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        { "_unparseable" => e.message.lines.first.to_s.strip }
      end

      def self.label(path)
        Pathname.new(path).relative_path_from(Rails.root).to_s
      rescue ArgumentError
        path.to_s
      end

      # v1 is the same entries without ops or a format marker. v1 wrote a version whose
      # overrides were all cleared with none of them; v2 spells that suppressed_boosts [].
      def self.from_v1(doc)
        return doc unless doc.is_a?(Hash) && !doc.key?("_unparseable")

        versions = Array(doc["versions"]).map do |entry|
          entry.is_a?(Hash) && !entry.keys.intersect?(WeaponSkills::OverlaySchema::OVERRIDES) ? entry.merge("suppressed_boosts" => []) : entry
        end
        doc.slice("effects", "data").merge("format" => 2, "versions" => versions)
      end

      # Identities, as the sync matches them. Two entries with one identity would
      # overwrite each other on every deploy, so that's an error wherever they are.
      def self.identity(section, entry)
        ref = [entry["weapon"], entry["skill"], entry["ordinal"]]
        case section
        when "versions" then ref
        when "effects" then ref + [entry["modifier"], entry["boost_type"], entry["key_slug"], sorted(entry["condition"] || {})]
        when "data" then ref + [entry["modifier"], entry["boost_type"], entry["series"], entry["size"]]
        when "ops" then ref + [entry["op"]]
        end
      end

      def self.sorted(value)
        value.is_a?(Hash) ? value.sort.to_h.transform_values { |v| sorted(v) } : value
      end

      # File-order keys: weapon, skill, ordinal, then what tells entries of one version apart.
      def self.sort_key(section, entry)
        base = [entry["weapon"].to_s, entry["skill"].to_s, entry["ordinal"].to_i]
        case section
        when "versions" then base
        when "ops" then base + [OP_ORDER.index(entry["op"]).to_i]
        else base + [entry["modifier"].to_s, entry["boost_type"].to_s, sorted(entry["condition"] || {}).to_json,
                     entry["key_slug"].to_s, entry["series"].to_s, entry["size"].to_s]
        end
      end

      def validate!
        errors = files.flat_map do |label, doc|
          next ["#{label}: not valid JSON (#{doc['_unparseable']})"] if doc.is_a?(Hash) && doc.key?("_unparseable")

          WeaponSkills::OverlaySchema.validate(doc).map { |e| "#{label}: #{e}" }
        end
        errors.concat(duplicate_errors) if errors.empty?
        raise Invalid, "curation overlay is invalid; nothing was applied:\n  #{errors.join("\n  ")}" if errors.any?

        self
      end

      def entries(section)
        files.flat_map { |_, doc| Array(doc[section]) }
      end

      def to_h
        SECTIONS.index_with { |section| entries(section) }
      end

      private

      def duplicate_errors
        SECTIONS.flat_map do |section|
          seen = {}
          files.flat_map do |label, doc|
            Array(doc[section]).each_with_index.filter_map do |entry, i|
              key = self.class.identity(section, entry)
              where = "#{label} #{section}[#{i}]"
              unless seen.key?(key)
                seen[key] = where
                next
              end

              "#{where}: same identity as #{seen[key]} (#{key.compact.first(5).join(' / ')})"
            end
          end
        end
      end
    end
  end
end
