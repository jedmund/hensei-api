# frozen_string_literal: true

# Rewrites every percent-encoded wiki_ja (characters, weapons, summons) as the plain UTF-8
# gbf-wiki.com title, so stored titles are readable and links and fetches don't have to guess
# the encoding. Most legacy rows are EUC-JP (%A5%BC%A5%D8%A5%AF%20%28R%29 = ゼヘク (R)); a
# few are UTF-8 with + for spaces. Granblue::JpWikiTitle decodes both.
#
# A value that decodes to neither (cut off mid-escape, a lost %) is left as it is; its
# granblue_id is logged for an editor to fix. Logs counts and ids only. update_all writes
# the column alone: no callbacks, no skill builds. Rerunnable: converted rows no longer match.
class DecodePercentEncodedJpWikiTitles < ActiveRecord::Migration[8.1]
  TABLES = %w[characters weapons summons].freeze
  ENCODED = "wiki_ja ~ '%[0-9A-Fa-f]{2}'"
  BATCH = 500

  def up
    TABLES.each { |table| decode(table) }
  end

  def down
    # Nothing to undo: the decoded title names the same page.
  end

  private

  def decode(table)
    model = Class.new(ActiveRecord::Base) { self.table_name = table }
    counts = Hash.new(0)
    undecodable = []

    model.where(ENCODED).in_batches(of: BATCH) do |batch|
      batch.pluck(:id, :granblue_id, :wiki_ja).each do |id, granblue_id, title|
        title_text, encoding = Granblue::JpWikiTitle.decode_with_encoding(title)
        if title_text.nil?
          undecodable << granblue_id
          next
        end

        model.where(id: id).update_all(wiki_ja: title_text)
        counts[encoding] += 1
      end
    end

    say "#{table}: decoded #{counts[:utf8]} UTF-8 and #{counts[:euc_jp]} EUC-JP titles"
    say "#{table}: #{undecodable.size} undecodable, left as they are: #{undecodable.join(', ')}" if undecodable.any?
  end
end
