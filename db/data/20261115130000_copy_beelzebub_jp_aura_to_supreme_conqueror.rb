# frozen_string_literal: true

# The Supreme Conqueror (2040458000, 至高無上の金剛覇者) has no page on gbf-wiki.com yet, so
# it has no Japanese aura text (GBF-57). Its aura is identical to Beelzebub's (2040408000):
# every English tier matches word for word, checked in game. Only the aura's name differs.
#
# This copies the 加護 rows of Beelzebub's stored Japanese page, with the tier colors the
# parser reads, into The Supreme Conqueror's wiki_raw_jp, renaming the aura from
# 一にして全、全にして一 to 闘争の果て、力の頂. Nothing else of Beelzebub's page is copied.
#
# A page of its own always wins: this writes only when The Supreme Conqueror has no stored
# page or holds an earlier copy. Rerunnable.
class CopyBeelzebubJpAuraToSupremeConqueror < ActiveRecord::Migration[8.1]
  SOURCE = '2040408000' # Beelzebub
  TARGET = '2040458000' # The Supreme Conqueror
  SOURCE_NAME = '一にして全、全にして一'
  TARGET_NAME = '闘争の果て、力の頂'
  MARKER = %(data-copied-from="#{SOURCE}").freeze

  def up
    target = Summon.find_by(granblue_id: TARGET)
    return say('The Supreme Conqueror not found') unless target
    return say('The Supreme Conqueror has its own page; left alone') if own_page?(target.wiki_raw_jp)

    rows = aura_rows(Summon.find_by(granblue_id: SOURCE)&.wiki_raw_jp)
    return say('Beelzebub has no stored aura rows; nothing copied') unless rows&.include?(SOURCE_NAME)

    html = %(<div id="body" #{MARKER}><table class="style_table"><tbody>) \
           "#{rows.sub(SOURCE_NAME, TARGET_NAME)}</tbody></table></div>"
    return say('The Supreme Conqueror already holds this copy') if target.wiki_raw_jp == html

    target.update!(wiki_raw_jp: html, wiki_raw_jp_fetched_at: Time.current)
    say "copied Beelzebub's Japanese aura to The Supreme Conqueror as #{TARGET_NAME}"
  end

  def down
    # Nothing to undo: the copy matches the summon's aura.
  end

  private

  def own_page?(html)
    html.present? && html.exclude?(MARKER)
  end

  # The rows from the 加護 header to just before the フレーバーテキスト row.
  def aura_rows(html)
    html = html.to_s
    header = html.index(%r{<th[^>]*>\s*加護\s*</th>})
    return unless header

    flavor = html.index('フレーバーテキスト', header)
    start = html.rindex('<tr', header)
    finish = flavor && html.rindex('<tr', flavor)
    html[start...finish] if start && finish && finish > start
  end
end
