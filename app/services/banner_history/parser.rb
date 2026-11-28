# frozen_string_literal: true

module BannerHistory
  # Reads the {{GachaBanner}} templates on a Banner History page into plain
  # hashes. Pure: no lookups, no times; Timeline and Resolver take it from here.
  #
  #   Parser.parse(wikitext) # → [{ type:, start_date:, name:, fields: { 'rateup_wep_ssr' => [...] } }]
  module Parser
    # Fields holding ;-separated item lists
    LIST_FIELD = /\A(rateup_|sparkable|zodiacs\z|collab_|noncollab_|legacy_)/

    module_function

    # source_key: the page the banners came from, kept on each
    def parse(wikitext, source_key: nil)
      wikitext.to_s.scan(/\{\{GachaBanner(.*?)\n?\}\}/m).map { |(body)| banner(body).merge(source_key: source_key) }
    end

    def banner(body)
      fields = body.scan(/^\|\s*([a-z0-9_]+)\s*=(.*)$/).to_h { |key, value| [key, value.strip] }
      {
        type: fields['type'].to_s.strip,
        start_date: date(fields['start_date']),
        start_time: fields['start_time'].presence,
        end_date: date(fields['end_date']),
        end_time: fields['end_time'].presence,
        name: fields['name'].presence,
        news_url: fields['news_url'].presence,
        lists: fields.select { |key, _| key.match?(LIST_FIELD) }.transform_values { |value| list(value) }.reject { |_, v| v.empty? },
        rates: fields.select { |key, value| key.start_with?('prc_') && value.present? }
      }
    end

    def list(value)
      value.to_s.split(';').map(&:strip).reject(&:empty?)
    end

    def date(value)
      Date.iso8601(value.to_s.strip)
    rescue Date::Error
      nil
    end
  end
end
