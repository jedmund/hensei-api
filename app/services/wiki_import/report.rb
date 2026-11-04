# frozen_string_literal: true

module WikiImport
  ##
  # What a wiki import matched, couldn't match and warned about, in the order
  # it found them. Every entry says what it's about with kind, position and
  # title (as pasted).
  class Report
    def initialize
      @entries = { matched: [], unmatched: [], ambiguous: [], warnings: [] }
    end

    # @return [Hash] the report the API answers with
    def to_h = @entries

    def matched(kind, position, title, item)
      @entries[:matched] << { kind: kind.to_s, position: position, title: title, item: item }
    end

    def unmatched(kind, entry)
      @entries[:unmatched] << { kind: kind.to_s, position: entry.position, title: entry.title }
    end

    def ambiguous(kind, entry, candidates)
      @entries[:ambiguous] << { kind: kind.to_s, position: entry.position, title: entry.title, candidates: candidates }
    end

    # Every warning has a code and a detail.
    #
    # @return [nil]
    def warn(code, detail, kind: nil, position: nil, title: nil)
      about = { kind: kind&.to_s, position: position, title: title }.compact
      @entries[:warnings] << { code: code, detail: detail.to_s, **about }
      nil
    end

    # What a payload item is: its kind, position and title.
    def self.at(kind, entry)
      { kind: kind, position: entry.position, title: entry.title }
    end

    def self.item_json(record, element)
      named_json(record).merge(element: element)
    end

    def self.named_json(record)
      json = { id: record.id }
      json[:granblueId] = record.granblue_id if record.respond_to?(:granblue_id)
      json.merge(name: { en: record.name_en, ja: record.name_jp })
    end
  end
end
