# frozen_string_literal: true

module Granblue
  module Parsers
    # Labels that are only another spelling or form of their status's name (D60): "Shield" on a
    # Shielded effect, "Charge Boost" on Charge Bar. data/statuses/spelling_labels.json lists them as
    # [{ label, status, reason }]; the effect parser drops a label in the list, so the status reads the
    # same everywhere. A curated list rather than a fuzzy rule, so what's dropped is predictable and
    # reviewable; a label not in it is kept.
    module SpellingLabels
      PATH = Rails.root.join('data/statuses/spelling_labels.json')

      module_function

      def spelling?(label, status_name)
        pairs.include?([Status.normalize_name(label), Status.normalize_name(status_name)])
      end

      def pairs
        @pairs ||= load
      end

      def reset!
        @pairs = nil
      end

      def load(path = PATH)
        return Set.new unless File.file?(path) && File.size(path).positive?

        JSON.parse(File.read(path)).to_set do |entry|
          [Status.normalize_name(entry.fetch('label')), Status.normalize_name(entry.fetch('status'))]
        end
      end

      def sha256(path = PATH)
        File.file?(path) ? Digest::SHA256.file(path).hexdigest : '-'
      end
    end
  end
end
