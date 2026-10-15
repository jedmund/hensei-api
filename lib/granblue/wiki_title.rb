# frozen_string_literal: true

module Granblue
  # A gbf.wiki page title in MediaWiki's canonical form: percent-decoded, trimmed, with
  # spaces rather than underscores ("Devil%27s_Finger" → "Devil's Finger"). Stored titles
  # (wiki_en, weapon_sources keys) use it so every lookup compares like with like; URLs
  # encode it when they're built.
  module WikiTitle
    PERCENT_ESCAPE = /%[0-9A-Fa-f]{2}/

    module_function

    def normalize(title)
      return nil if title.nil?

      text = title.to_s
      if text.match?(PERCENT_ESCAPE)
        decoded = URI.decode_uri_component(text)
        text = decoded if decoded.valid_encoding?
      end
      text.tr("_", " ").gsub(/\s+/, " ").strip
    end
  end
end
