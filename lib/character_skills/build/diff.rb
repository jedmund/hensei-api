# frozen_string_literal: true

module CharacterSkills
  module Build
    # Compares two Snapshot entries for one character, version by version. Each Change is one
    # line of contract C6's `changes` (#to_h): the version's natural key, its name, created /
    # updated / deleted, and the fields that differ (column names, plus "effects", "links",
    # "slot_game_action_id" and "duplicates").
    module Diff
      KIND_ORDER = %w[ability ougi support].freeze
      # Shadow output groups changes by these; a change can touch several.
      CATEGORY_FIELDS = {
        "icon" => %w[icon game_icon],
        "name" => %w[name_en name_jp],
        "description" => %w[description_en description_jp],
        "effects" => %w[effects]
      }.freeze
      STRUCTURE_FIELDS = %w[links duplicates ordinal].freeze
      CATEGORIES = %w[structure icon name description effects other].freeze

      Change = Struct.new(:kind, :position, :ordinal, :change, :fields, :before, :after, keyword_init: true) do
        def entry = after || before
        def name = { en: entry["name_en"], ja: entry["name_jp"] }
        def label = Diff.key_label([kind, position, ordinal])

        def to_h
          { kind: kind, position: position, ordinal: ordinal, name: name, change: change, fields: fields }
        end

        def categories
          return ["structure"] unless change == "updated"

          found = CATEGORY_FIELDS.filter_map { |category, columns| category if fields.intersect?(columns) }
          found.unshift("structure") if fields.intersect?(STRUCTURE_FIELDS)
          known = CATEGORY_FIELDS.values.flatten + STRUCTURE_FIELDS
          found << "other" if (fields - known).any?
          found
        end
      end

      module_function

      # before/after: { [kind, position, ordinal] => entry } → [Change], in slot order.
      def between(before, after)
        before ||= {}
        after ||= {}
        changes = (before.keys | after.keys).filter_map do |key|
          b = before[key]
          a = after[key]
          kind, position, ordinal = key
          if b.nil?
            Change.new(kind: kind, position: position, ordinal: ordinal, change: "created", fields: [], after: a)
          elsif a.nil?
            Change.new(kind: kind, position: position, ordinal: ordinal, change: "deleted", fields: [], before: b)
          else
            fields = (b.keys | a.keys).reject { |field| b[field] == a[field] }.sort
            Change.new(kind: kind, position: position, ordinal: ordinal, change: "updated", fields: fields, before: b, after: a) if fields.any?
          end
        end
        changes.sort_by { |c| [KIND_ORDER.index(c.kind) || KIND_ORDER.size, c.position.to_i, c.ordinal.to_i] }
      end

      def key_label(key)
        key ? key.join(":") : "?"
      end
    end
  end
end
