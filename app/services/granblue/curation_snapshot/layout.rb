# frozen_string_literal: true

module Granblue
  class CurationSnapshot
    # Files overlay entries by weapon series and writes them, sorted, one file per
    # series (docs/weapon-skill-pipeline/overlay-v2.md). Canonical rows go in
    # _canonical.json; weapons with no series (or not in this catalogue) in _none.json.
    class Layout
      def initialize(dir)
        @dir = Pathname.new(dir)
      end

      # sections: { "versions" => [...], "effects" => [...], "data" => [...], "ops" => [...] }
      # → { file name => document }
      def documents(sections)
        slugs = series_slugs(sections.values.flatten.filter_map { |entry| entry["weapon"] }.uniq)
        files = Hash.new { |h, name| h[name] = Overlay::SECTIONS.index_with { [] } }
        Overlay::SECTIONS.each do |section|
          Array(sections[section]).each { |entry| files[file_for(entry, slugs)][section] << entry }
        end
        files.sort.to_h.transform_values do |doc|
          { "format" => 2 }.merge(doc.to_h { |section, entries| [section, sort(section, entries)] })
        end
      end

      # Writes the documents and removes overlay files that no longer have entries.
      # → the documents written, by file name.
      def write(sections)
        docs = documents(sections)
        FileUtils.mkdir_p(@dir)
        docs.each { |name, doc| File.write(@dir.join(name), "#{JSON.pretty_generate(doc)}\n") }
        Dir.glob(@dir.join("*.json").to_s).each { |path| FileUtils.rm_f(path) unless docs.key?(File.basename(path)) }
        docs
      end

      private

      def file_for(entry, slugs)
        return Overlay::CANONICAL_FILE if entry["weapon"].nil?

        slug = slugs[entry["weapon"]]
        slug ? "#{slug}.json" : Overlay::NO_SERIES_FILE
      end

      def series_slugs(weapon_ids)
        Weapon.joins(:weapon_series).where(granblue_id: weapon_ids).pluck(:granblue_id, "weapon_series.slug").to_h
      end

      def sort(section, entries)
        entries.sort_by { |entry| Overlay.sort_key(section, entry) }.map { |entry| ordered(entry) }
      end

      # Reference fields first, so every entry reads weapon / skill / ordinal / ….
      def ordered(entry)
        head = entry.slice("op", "weapon", "skill", "ordinal")
        tail = entry.except(*head.keys, "edited_at")
        head.merge(tail).merge(entry.slice("edited_at"))
      end
    end
  end
end
