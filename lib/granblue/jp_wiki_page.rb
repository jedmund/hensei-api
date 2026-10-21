# frozen_string_literal: true

require 'nokogiri'

module Granblue
  # The part of a gbf-wiki.com page worth storing (D35). Every reader of a character's
  # JP page (JpWikiSkillParser, CharacterSkills::JpLocalizer, the stat audit's
  # JpWikiStatParser) starts at div#body, so the rest (head, menus, sidebar, footer,
  # scripts: about three quarters of the page) is dropped before the page is stored.
  #
  # The fetch path (JpWikiDownloader) and the copy into `sources` both go through
  # .trim, so a refetch of an unchanged page compares equal to what's stored.
  module JpWikiPage
    module_function

    # → div#body's HTML, or html unchanged when it has no div#body (an error page or
    # an already-trimmed body parse the same either way). UTF-8 in and out, so kana
    # stay literal instead of turning into numeric entities.
    def trim(html)
      return html if html.blank? || trimmed?(html)

      body = Nokogiri::HTML(html, nil, 'UTF-8').at_css('div#body')
      return html if body.nil?

      body.to_html(encoding: 'UTF-8')
    end

    # Already a trimmed page (it starts with the div#body element), so trimming twice is
    # the same as once: a refetch compares equal byte for byte.
    def trimmed?(html)
      html.match?(/\A<div\b[^>]*\bid="body"/)
    end
  end
end
