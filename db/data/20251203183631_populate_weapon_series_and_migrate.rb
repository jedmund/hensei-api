# frozen_string_literal: true

class PopulateWeaponSeriesAndMigrate < ActiveRecord::Migration[8.0]
  def up
    # Canonical weapon series data with correct names, ordering, and flags
    # The legacy_id matches the integer values currently in Weapon.series column
    # Order: Gacha first (0), main series (1-37), misc series (38-44), Event last (99)
    weapon_series_data = [
      # Gacha is first
      { legacy_id: 99, order: 0, slug: 'gacha', name_en: 'Gacha Weapons', name_jp: 'ガチャ武器' },
      # Main series in canonical order
      { legacy_id: 1, order: 1, slug: 'seraphic', name_en: 'Seraphic Weapons', name_jp: 'セラフィックウェポン' },
      { legacy_id: 2, order: 2, slug: 'grand', name_en: 'Grand Weapons', name_jp: 'リミテッドシリーズ', has_weapon_keys: true },
      { legacy_id: 3, order: 3, slug: 'dark-opus', name_en: 'Dark Opus Weapons', name_jp: '終末の神器', has_weapon_keys: true, has_awakening: true },
      # Destroyer is a new series - no legacy_id mapping yet
      { legacy_id: nil, order: 4, slug: 'destroyer', name_en: 'Destroyer Weapons', name_jp: '破壊の標' },
      { legacy_id: 27, order: 5, slug: 'draconic', name_en: 'Draconic Weapons', name_jp: 'ドラコニックウェポン・オリジン', has_weapon_keys: true, has_awakening: true },
      { legacy_id: 40, order: 6, slug: 'draconic-providence', name_en: 'Draconic Weapons Providence', name_jp: 'ドラコニックウェポン', has_weapon_keys: true, has_awakening: true },
      { legacy_id: 30, order: 7, slug: 'new-world-foundation', name_en: 'New World Foundation', name_jp: '新世界の礎' },
      { legacy_id: 26, order: 8, slug: 'astral', name_en: 'Astral Weapons', name_jp: 'アストラルウェポン' },
      { legacy_id: 13, order: 9, slug: 'ultima', name_en: 'Ultima Weapons', name_jp: 'オメガウェポン', element_changeable: true, has_weapon_keys: true },
      { legacy_id: 14, order: 10, slug: 'bahamut', name_en: 'Bahamut Weapons', name_jp: 'バハムートウェポン' },
      { legacy_id: 16, order: 11, slug: 'cosmos', name_en: 'Cosmos Weapons', name_jp: 'コスモスシリーズ', extra: true },
      { legacy_id: 10, order: 12, slug: 'hollowsky', name_en: 'Hollowsky Weapons', name_jp: '虚ろなる神器' },
      { legacy_id: 8, order: 13, slug: 'omega', name_en: 'Omega Weapons', name_jp: 'マグナシリーズ' },
      { legacy_id: 7, order: 14, slug: 'regalia', name_en: 'Regalia Weapons', name_jp: 'レガリアシリーズ' },
      { legacy_id: 42, order: 15, slug: 'omega-rebirth', name_en: 'Omega Rebirth Weapons', name_jp: 'マグナ・リバースシリーズ' },
      { legacy_id: 33, order: 16, slug: 'malice', name_en: 'Malice Weapons', name_jp: 'マリスシリーズ' },
      { legacy_id: 34, order: 17, slug: 'menace', name_en: 'Menace Weapons', name_jp: 'メネスシリーズ', extra: true, has_weapon_keys: true },
      { legacy_id: 31, order: 18, slug: 'ennead', name_en: 'Ennead Weapons', name_jp: 'エニアドシリーズ' },
      { legacy_id: 29, order: 19, slug: 'ancestral', name_en: 'Ancestral Weapons', name_jp: 'アンセスタルシリーズ', extra: true },
      { legacy_id: 37, order: 20, slug: 'revans', name_en: 'Revans Weapons', name_jp: 'レヴァンスウェポン' },
      { legacy_id: 4, order: 21, slug: 'revenant', name_en: 'Revenant Weapons', name_jp: '天星器', element_changeable: true },
      { legacy_id: 41, order: 22, slug: 'celestial', name_en: 'Celestial Weapons', name_jp: '極星器' },
      { legacy_id: 11, order: 23, slug: 'xeno', name_en: 'Xeno Weapons', name_jp: '六道武器', extra: true },
      { legacy_id: 39, order: 24, slug: 'exo', name_en: 'Exo Weapons', name_jp: 'エクスウェポン' },
      { legacy_id: 6, order: 25, slug: 'beast', name_en: 'Beast Weapons', name_jp: '四象武器' },
      { legacy_id: 36, order: 26, slug: 'proven', name_en: 'Proven Weapons', name_jp: 'ブレイブウェポン' },
      { legacy_id: 17, order: 27, slug: 'superlative', name_en: 'Superlative Weapons', name_jp: 'スペリオシリーズ', extra: true, element_changeable: true, has_weapon_keys: true },
      { legacy_id: 35, order: 28, slug: 'illustrious', name_en: 'Illustrious Weapons', name_jp: 'ルミナスシリーズ' },
      { legacy_id: 18, order: 29, slug: 'vintage', name_en: 'Vintage Weapons', name_jp: 'ヴィンテージシリーズ' },
      { legacy_id: 19, order: 30, slug: 'class-champion', name_en: 'Class Champion Weapons', name_jp: '英雄武器', element_changeable: true },
      { legacy_id: 12, order: 31, slug: 'rose', name_en: 'Rose Weapons', name_jp: 'ローズシリーズ' },
      { legacy_id: 5, order: 32, slug: 'primal', name_en: 'Primal Weapons', name_jp: 'プライマルシリーズ' },
      { legacy_id: 9, order: 33, slug: 'olden-primal', name_en: 'Olden Primal Weapons', name_jp: 'オールド・プライマルシリーズ' },
      { legacy_id: 15, order: 34, slug: 'epic', name_en: 'Epic Weapons', name_jp: 'エピックウェポン' },
      { legacy_id: 32, order: 35, slug: 'militis', name_en: 'Militis Weapons', name_jp: 'ミーレスシリーズ', extra: true },
      { legacy_id: 23, order: 36, slug: 'sephira', name_en: 'Sephira Weapons', name_jp: 'セフィラン・オールドウェポン' },
      { legacy_id: 38, order: 37, slug: 'world', name_en: 'World Weapons', name_jp: 'ワールドシリーズ' },
      # Misc series at the end (before Event): Replicas, Rusted, Relics, Eternal Splendor, Vyrmament, Collab
      { legacy_id: 20, order: 38, slug: 'replica', name_en: 'Replica Weapons', name_jp: 'レプリカ' },
      { legacy_id: 22, order: 39, slug: 'rusted', name_en: 'Rusted Weapons', name_jp: '朽ち果てた武器' },
      { legacy_id: 21, order: 40, slug: 'relic', name_en: 'Relic Weapons', name_jp: 'リビルド' },
      { legacy_id: 28, order: 41, slug: 'eternal-splendor', name_en: 'Eternal Splendor Weapons', name_jp: '極光の証', extra: true },
      { legacy_id: 24, order: 42, slug: 'vyrmament', name_en: 'Vyrmament Weapons', name_jp: 'バーミアントシリーズ', has_weapon_keys: true },
      { legacy_id: 43, order: 43, slug: 'collab', name_en: 'Collab Weapons', name_jp: 'コラボ武器' },
      # Upgrader (not in canonical list, keeping for legacy support)
      { legacy_id: 25, order: 44, slug: 'upgrader', name_en: 'Upgrader Weapons', name_jp: 'アップグレーダー' },
      # Event is last
      { legacy_id: 98, order: 99, slug: 'event', name_en: 'Event Weapons', name_jp: 'イベント武器' }
    ]

    # Build mapping from legacy series integer to new weapon_series_id
    legacy_to_uuid = {}

    puts "Creating/updating weapon series records..."
    weapon_series_data.each do |data|
      ws = WeaponSeries.find_or_initialize_by(slug: data[:slug])
      ws.assign_attributes(
        name_en: data[:name_en],
        name_jp: data[:name_jp],
        order: data[:order],
        extra: data[:extra] || false,
        element_changeable: data[:element_changeable] || false,
        has_weapon_keys: data[:has_weapon_keys] || false,
        has_awakening: data[:has_awakening] || false,
        has_ax_skills: data[:has_ax_skills] || false
      )
      ws.save!
      legacy_to_uuid[data[:legacy_id]] = ws.id if data[:legacy_id].present?
      puts "  #{ws.slug}: #{ws.name_en}"
    end

    puts "\nMigrating weapons to use weapon_series_id..."
    migrated = 0
    skipped = 0

    Weapon.find_each do |weapon|
      next if weapon.series.blank?

      weapon_series_id = legacy_to_uuid[weapon.series.to_i]
      if weapon_series_id
        weapon.update_column(:weapon_series_id, weapon_series_id)
        migrated += 1
      else
        puts "  Warning: No weapon_series found for legacy series #{weapon.series} (weapon: #{weapon.name_en})"
        skipped += 1
      end
    end

    puts "  Migrated #{migrated} weapons, skipped #{skipped}"

    puts "\nMigrating weapon_key series to weapon_key_series join table..."
    key_count = 0

    WeaponKey.find_each do |weapon_key|
      next if weapon_key.series.blank?

      weapon_key.series.each do |legacy_series_id|
        weapon_series_id = legacy_to_uuid[legacy_series_id.to_i]
        next unless weapon_series_id

        # Create join record if it doesn't exist
        WeaponKeySeries.find_or_create_by!(
          weapon_key_id: weapon_key.id,
          weapon_series_id: weapon_series_id
        )
        key_count += 1
      end
    end

    puts "  Created #{key_count} weapon_key_series associations"
    puts "\nWeapon series migration complete!"
  end

  def down
    # Remove all weapon_key_series records
    WeaponKeySeries.delete_all

    # Clear weapon_series_id from all weapons
    Weapon.update_all(weapon_series_id: nil)

    # Delete all weapon_series records
    WeaponSeries.delete_all
  end
end
