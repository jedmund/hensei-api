# frozen_string_literal: true

class ChangeSubstitutionNoteToJsonb < ActiveRecord::Migration[8.0]
  TABLES = %i[grid_characters grid_weapons grid_summons].freeze

  def up
    TABLES.each do |table|
      # Existing values are plain text. Wrap each non-null string into a Tiptap
      # doc shape so the frontend doesn't have to special-case legacy rows.
      change_column(
        table,
        :substitution_note,
        :jsonb,
        using: <<~SQL.squish
          CASE
            WHEN substitution_note IS NULL OR substitution_note = '' THEN NULL
            ELSE jsonb_build_object(
              'type', 'doc',
              'content', jsonb_build_array(
                jsonb_build_object(
                  'type', 'paragraph',
                  'content', jsonb_build_array(
                    jsonb_build_object('type', 'text', 'text', substitution_note)
                  )
                )
              )
            )
          END
        SQL
      )
    end
  end

  def down
    TABLES.each do |table|
      change_column(
        table,
        :substitution_note,
        :text,
        using: 'substitution_note::text'
      )
    end
  end
end
