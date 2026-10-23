# frozen_string_literal: true

# One table for every fetched input (D34/D35): wiki pages, game payloads and shared
# lists, as the current body plus its sha256. A row is either owned by a record
# (owner_type/owner_id, e.g. a character's wiki_raw) or shared (no owner, e.g. the
# wiki status list), and is unique per (owner, kind, key) or (kind, key).
#
# body is compressed with lz4 where the server supports it (PostgreSQL 14+ built with
# lz4); elsewhere it keeps the default pglz. schema.rb doesn't record the compression.
class CreateSources < ActiveRecord::Migration[8.1]
  KINDS = %w[wiki_raw wiki_raw_jp game_raw_en game_raw_jp wiki_status_list].freeze

  def up
    create_table :sources, id: :uuid do |t|
      t.string :kind, null: false
      # '' for a record's single source of a kind; NULL would slip past the unique indexes.
      t.string :key, null: false, default: ''
      t.text :body, null: false
      t.string :sha256, null: false, limit: 64
      t.datetime :fetched_at
      t.string :owner_type
      t.uuid :owner_id
      t.timestamps
    end

    add_index :sources, %i[owner_type owner_id kind key], unique: true,
                                                          where: 'owner_id IS NOT NULL',
                                                          name: 'index_sources_on_owner_kind_key'
    add_index :sources, %i[kind key], unique: true, where: 'owner_id IS NULL',
                                      name: 'index_sources_on_shared_kind_key'
    add_check_constraint :sources, "kind IN (#{KINDS.map { |kind| quote(kind) }.join(', ')})", name: 'sources_kind'
    add_check_constraint :sources, '(owner_type IS NULL) = (owner_id IS NULL)', name: 'sources_owner_pair'

    use_lz4
  end

  def down
    drop_table :sources
  end

  private

  def quote(value)
    connection.quote(value)
  end

  def use_lz4
    return say('body: PostgreSQL < 14, keeping pglz') if select_value('SHOW server_version_num').to_i < 140_000

    connection.transaction(requires_new: true) do
      execute 'ALTER TABLE sources ALTER COLUMN body SET COMPRESSION lz4'
    end
    say 'body: lz4 compression'
  rescue ActiveRecord::StatementInvalid => e
    say "body: lz4 unavailable (#{e.message.lines.first.strip}), keeping pglz"
  end
end
