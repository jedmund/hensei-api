# frozen_string_literal: true

# Loads the committed character skill icon snapshot (data/character_skills/icons.json) into its
# `sources` row (kind icon_snapshot, key character_skills), where CharacterSkills::IconSnapshot
# reads it now (D34, PR 7b). The body is the file byte for byte, so the row's sha256 is the
# file's digest and character build fingerprints don't change. A follow-up deletes the file.
#
# Idempotent: an existing row is kept (an export through the store since wins). Logs counts only.
class LoadCharacterSkillIconSnapshot < ActiveRecord::Migration[8.1]
  PATH = Rails.root.join('data/character_skills/icons.json')
  KIND = 'icon_snapshot'
  KEY = 'character_skills'

  def up
    if Source.exists?(owner_type: nil, owner_id: nil, kind: KIND, key: KEY)
      say 'icon snapshot: already stored, kept'
    elsif !File.file?(PATH)
      say 'icon snapshot: no file, nothing stored'
    else
      text = File.binread(PATH).force_encoding(Encoding::UTF_8)
      Source.put(nil, KIND, text, key: KEY, fetched_at: nil)
      say "icon snapshot: stored #{JSON.parse(text).size} entries"
    end
  end

  def down
    # Nothing to undo: the file stays until the follow-up deletes it, and the row matches it.
  end
end
