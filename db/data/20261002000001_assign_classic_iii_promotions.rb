# frozen_string_literal: true

require 'csv'

# Membership is an explicit, reviewed catalogue manifest, never a date inference.
class AssignClassicIiiPromotions < ActiveRecord::Migration[8.0]
  PROMOTION = 12
  ORDINARY_PROMOTIONS = [1, 4, 5, 6, 7, 8, 9].freeze
  MANIFEST = File.expand_path('manifests/classic_iii.csv', __dir__)

  def up
    transaction do
      execute 'LOCK TABLE weapons, summons IN SHARE ROW EXCLUSIVE MODE'
      preview.each do |entry|
        next if entry[:before] == entry[:after]
        execute "UPDATE #{entry[:table]} SET promotions = ARRAY[#{entry[:after].join(',')}]::integer[] WHERE id = #{connection.quote(entry[:id])}"
      end
    end
  end

  # Resolves every identifier before any mutation; missing/duplicate IDs abort.
  # Also usable from rails runner to review exact before/after arrays.
  def preview
    entries = CSV.read(MANIFEST, headers: true)
    keys = entries.map { |entry| [entry['type'], entry['granblue_id']] }
    raise 'Duplicate identifiers in Classic III manifest' unless keys.uniq.length == keys.length

    entries.map do |entry|
      table = { 'Weapon' => 'weapons', 'Summon' => 'summons' }.fetch(entry['type'])
      rows = connection.select_all("SELECT id, rarity, promotions#{table == 'weapons' ? ', recruits' : ''} FROM #{table} WHERE granblue_id = #{connection.quote(entry['granblue_id'])}").to_a
      raise "Expected exactly one #{entry['type']} #{entry['granblue_id']}; found #{rows.length}" unless rows.length == 1

      expected_rarity = { 'SSR' => 3, 'SR' => 2, 'R' => 1 }.fetch(entry['rarity'])
      raise "Rarity mismatch for #{entry['granblue_id']}" unless expected_rarity == rows.first['rarity'].to_i
      if entry['recruits'].present? && rows.first['recruits'] != entry['recruits']
        raise "Recruitment mismatch for #{entry['granblue_id']}"
      end

      before = ActiveRecord::Type.lookup(:integer, array: true, adapter: :postgresql).deserialize(rows.first['promotions']) || []
      removed = entry['availability'] == 'exclusive' ? ORDINARY_PROMOTIONS : []
      raise "Unknown availability #{entry['availability']}" unless %w[exclusive shared].include?(entry['availability'])

      { table: table, type: entry['type'], id: rows.first['id'], granblue_id: entry['granblue_id'], name: entry['name'],
        before: before, after: ((before - removed) + [PROMOTION]).uniq.sort, exclusive: entry['availability'] == 'exclusive' }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Previous availability differs per catalogue item; restore from a reviewed backup.'
  end

end
