# frozen_string_literal: true

module Granblue
  # A gbf-wiki.com (PukiWiki) page title as stored in wiki_ja: plain UTF-8 Japanese.
  #
  # Older rows hold the title percent-encoded, in one of two forms:
  #   - UTF-8 with + for spaces (what the wiki links to today):
  #     %E3%82%B8%E3%83%BC%E3%82%AF... = ジーク...
  #   - EUC-JP with %20 for spaces (the wiki's legacy encoding):
  #     %A5%BC%A5%D8%A5%AF%20%28R%29 = ゼヘク (R)
  # decode turns either into the plain title; URLs encode it when they're built.
  module JpWikiTitle
    PERCENT_ESCAPE = /%[0-9A-Fa-f]{2}/

    # A stored title that is percent-encoded but decodes to neither UTF-8 nor EUC-JP
    # (truncated, or some other encoding).
    class InvalidTitle < StandardError
      def initialize(msg = 'The stored Japanese wiki title (wiki_ja) is percent-encoded but is ' \
                           'neither UTF-8 nor EUC-JP; correct it in the editor')
        super
      end
    end

    module_function

    def encoded?(title)
      title.to_s.match?(PERCENT_ESCAPE)
    end

    # → the plain title, or the value as given (trimmed) when it can't be decoded: for
    # model attributes, which keep an undecodable value for an editor to fix.
    def normalize(title)
      return nil if title.nil?

      decode(title) || title.to_s.strip
    end

    # → the plain title (trimmed), or nil when the title is nil or undecodable.
    def decode(title)
      decode_with_encoding(title)&.first
    end

    # → the plain title; raises InvalidTitle when it can't be decoded.
    def decode!(title)
      return nil if title.nil?

      decode_with_encoding(title)&.first || raise(InvalidTitle)
    end

    # → [title, :plain | :utf8 | :euc_jp], or nil when the title is nil or undecodable.
    def decode_with_encoding(title)
      return nil if title.nil?

      text = title.to_s.strip
      return [text, :plain] unless encoded?(text)

      bytes = percent_decode(text)
      return nil if bytes.nil?

      utf8 = as_utf8(bytes)
      euc = as_euc_jp(bytes)
      # UTF-8 wins, unless only the EUC-JP reading is Japanese: a few EUC-JP byte pairs are
      # also valid UTF-8 (猫 = C7 AD reads as ǭ).
      return [utf8, :utf8] if utf8 && (japanese?(utf8) || !(euc && japanese?(euc)))
      return [euc, :euc_jp] if euc

      nil
    end

    def as_utf8(bytes)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      text.strip if text.valid_encoding?
    end

    def as_euc_jp(bytes)
      text = bytes.dup.force_encoding(Encoding::EUC_JP)
      text.encode(Encoding::UTF_8).strip if text.valid_encoding?
    rescue EncodingError
      nil
    end

    def japanese?(text)
      text.match?(/\p{Han}|\p{Hiragana}|\p{Katakana}/)
    end

    # Bytes of a query-string title (+ is a space). nil when a % starts no escape: the
    # title was cut off mid-escape.
    def percent_decode(text)
      spaced = text.tr('+', ' ')
      return nil if spaced.gsub(PERCENT_ESCAPE, '').include?('%')

      spaced.b.gsub(PERCENT_ESCAPE) { |escape| escape[1, 2].hex.chr }
    end
  end
end
