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
      return html if html.blank?

      body = Nokogiri::HTML(html, nil, 'UTF-8').at_css('div#body')
      return html if body.nil?

      body.to_html(encoding: 'UTF-8')
    end
  end
end
