# frozen_string_literal: true

module CharacterSkills
  module Build
    # Prints a shadow run's differences: per category (structure / icon / name / description /
    # effects / other), how many versions and characters it touches, then up to `limit` lines
    # grouped by category, each change under its first category.
    class Printer
      VALUE_FIELDS = (Diff::CATEGORY_FIELDS["icon"] + Diff::CATEGORY_FIELDS["name"] +
                      Diff::CATEGORY_FIELDS["description"]).freeze
      WIDTH = 70

      def initialize(summary, io:, limit: nil)
        @summary = summary
        @io = io
        @limit = limit
      end

      def print
        rows = @summary.results.flat_map { |result| result.changes.to_a.map { |change| [result.character, change] } }
        @io.puts "Differences: #{rows.size} versions across #{@summary.differing} characters"
        return if rows.empty?

        Diff::CATEGORIES.each do |category|
          touched = rows.select { |_, change| change.categories.include?(category) }
          next if touched.empty?

          @io.puts format("  %<category>-12s %<versions>5d versions, %<characters>4d characters",
                          category: category, versions: touched.size, characters: touched.map(&:first).uniq.size)
        end
        print_lines(rows)
      end

      private

      def print_lines(rows)
        shown = 0
        rows.group_by { |_, change| change.categories.first }.sort_by { |category, _| Diff::CATEGORIES.index(category) }
            .each do |category, group|
          break if @limit && shown >= @limit

          @io.puts "== #{category} (#{group.size})"
          group.each do |character, change|
            break if @limit && shown >= @limit

            @io.puts line(character, change)
            shown += 1
          end
        end
        @io.puts "… #{rows.size - shown} more differences not shown" if rows.size > shown
      end

      def line(character, change)
        head = "#{character.granblue_id} #{character.name_en}#{' (style)' if character.style_swap} " \
               "#{change.label} #{change.name[:en].inspect} #{change.change}"
        return head unless change.change == "updated"

        details = change.fields.map do |field|
          next field unless VALUE_FIELDS.include?(field)

          "#{field}: #{short(change.before[field])} → #{short(change.after[field])}"
        end
        "#{head}: #{details.join('; ')}"
      end

      def short(value)
        text = value.nil? ? "nil" : value.to_s
        text.length > WIDTH ? "#{text[0, WIDTH]}…".inspect : text.inspect
      end
    end
  end
end
