# frozen_string_literal: true

module Granblue
  module Parsers
    # Approved wiki spelling → canonical status name (data/statuses/aliases.json:
    # [{ wiki_name, name_en, reason }]). Empty until the user approves the rename list.
    module StatusAliases
      PATH = Rails.root.join('data/statuses/aliases.json')

      module_function

      def canonical(name)
        map[Status.normalize_name(name)] || name
      end

      def map
        @map ||= load
      end

      def reset!
        @map = nil
      end

      class Invalid < StandardError; end

      # Refuses an alias whose target is itself an alias: a name must reach its status in one step,
      # so StatusName.base(StatusName.base(x)) == StatusName.base(x).
      def load(path = PATH)
        return {} unless File.file?(path) && File.size(path).positive?

        map = JSON.parse(File.read(path)).to_h do |entry|
          [Status.normalize_name(entry.fetch('wiki_name')), entry.fetch('name_en').to_s.squish]
        end
        chained = map.values.select { |target| map.key?(Status.normalize_name(target)) }
        raise Invalid, "#{path}: aliases point at other aliases: #{chained.join(', ')}" if chained.any?

        map
      end

      def sha256(path = PATH)
        File.file?(path) ? Digest::SHA256.file(path).hexdigest : '-'
      end
    end
  end
end
