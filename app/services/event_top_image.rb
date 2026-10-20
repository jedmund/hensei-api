# frozen_string_literal: true

# Finds the header image of an event's gbf.wiki page: the first [[File:...]]
# before the page's first section heading (e.g. Dread_Barrage_top.jpg,
# "Event Unite and Fight header.jpg").
module EventTopImage
  module_function

  def file_name(wikitext)
    intro = wikitext.to_s.split(/^==/, 2).first.to_s
    intro[/\[\[File:([^|\]]+)/, 1]&.strip.presence
  end
end
