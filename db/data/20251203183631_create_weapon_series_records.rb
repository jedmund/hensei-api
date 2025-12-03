# frozen_string_literal: true

class CreateWeaponSeriesRecords < ActiveRecord::Migration[8.0]
  def up
    # Canonical weapon series data matching the frontend JSON exactly
    weapon_series_data = [
      { order: 0, slug: 'gacha', name_en: 'Gacha Weapons', name_jp: 'ガチャ武器' },
      { order: 1, slug: 'seraphic', name_en: 'Seraphic Weapons', name_jp: 'セラフィックウェポン' },
      { order: 2, slug: 'grand', name_en: 'Grand Weapons', name_jp: 'リミテッドシリーズ' },
      { order: 3, slug: 'dark-opus', name_en: 'Dark Opus Weapons', name_jp: '終末の神器', has_weapon_keys: true },
      { order: 4, slug: 'destroyer', name_en: 'Destroyer Weapons', name_jp: '破壊の標', extra: true, has_weapon_keys: true },
      { order: 5, slug: 'draconic', name_en: 'Draconic Weapons', name_jp: 'ドラコニックウェポン・オリジン', has_weapon_keys: true },
      { order: 6, slug: 'draconic-providence', name_en: 'Draconic Weapons Providence', name_jp: 'ドラコニックウェポン', extra: true, has_weapon_keys: true },
      { order: 7, slug: 'new-world-foundation', name_en: 'New World Foundation', name_jp: '新世界の礎', extra: true },
      { order: 8, slug: 'astral', name_en: 'Astral Weapons', name_jp: 'アストラルウェポン' },
      { order: 9, slug: 'ultima', name_en: 'Ultima Weapons', name_jp: 'オメガウェポン', element_changeable: true, has_weapon_keys: true },
      { order: 10, slug: 'bahamut', name_en: 'Bahamut Weapons', name_jp: 'バハムートウェポン', extra: true },
      { order: 11, slug: 'cosmos', name_en: 'Cosmos Weapons', name_jp: 'コスモスシリーズ' },
      { order: 12, slug: 'hollowsky', name_en: 'Hollowsky Weapons', name_jp: '虚ろなる神器' },
      { order: 13, slug: 'omega', name_en: 'Omega Weapons', name_jp: 'マグナシリーズ' },
      { order: 14, slug: 'regalia', name_en: 'Regalia Weapons', name_jp: 'レガリアシリーズ' },
      { order: 15, slug: 'omega-rebirth', name_en: 'Omega Rebirth Weapons', name_jp: 'マグナ・リバースシリーズ' },
      { order: 16, slug: 'malice', name_en: 'Malice Weapons', name_jp: 'マリスシリーズ' },
      { order: 17, slug: 'menace', name_en: 'Menace Weapons', name_jp: 'メネスシリーズ' },
      { order: 18, slug: 'ennead', name_en: 'Ennead Weapons', name_jp: 'エニアドシリーズ' },
      { order: 19, slug: 'ancestral', name_en: 'Ancestral Weapons', name_jp: 'アンセスタルシリーズ' },
      { order: 20, slug: 'revans', name_en: 'Revans Weapons', name_jp: 'レヴァンスウェポン', has_awakening: true },
      { order: 21, slug: 'revenant', name_en: 'Revenant Weapons', name_jp: '天星器', element_changeable: true },
      { order: 22, slug: 'celestial', name_en: 'Celestial Weapons', name_jp: '極星器', extra: true, has_awakening: true },
      { order: 23, slug: 'xeno', name_en: 'Xeno Weapons', name_jp: '六道武器' },
      { order: 24, slug: 'exo', name_en: 'Exo Weapons', name_jp: 'エクスウェポン', has_awakening: true },
      { order: 25, slug: 'beast', name_en: 'Beast Weapons', name_jp: '四象武器' },
      { order: 26, slug: 'proven', name_en: 'Proven Weapons', name_jp: 'ブレイブウェポン', has_awakening: true },
      { order: 27, slug: 'superlative', name_en: 'Superlative Weapons', name_jp: 'スペリオシリーズ', element_changeable: true },
      { order: 28, slug: 'illustrious', name_en: 'Illustrious Weapons', name_jp: 'ルミナスシリーズ' },
      { order: 29, slug: 'vintage', name_en: 'Vintage Weapons', name_jp: 'ヴィンテージシリーズ' },
      { order: 30, slug: 'class-champion', name_en: 'Class Champion Weapons', name_jp: '英雄武器', element_changeable: true, has_weapon_keys: true },
      { order: 31, slug: 'rose', name_en: 'Rose Weapons', name_jp: 'ローズシリーズ' },
      { order: 32, slug: 'primal', name_en: 'Primal Weapons', name_jp: 'プライマルシリーズ' },
      { order: 33, slug: 'olden-primal', name_en: 'Olden Primal Weapons', name_jp: 'オールド・プライマルシリーズ' },
      { order: 34, slug: 'epic', name_en: 'Epic Weapons', name_jp: 'エピックウェポン' },
      { order: 35, slug: 'militis', name_en: 'Militis Weapons', name_jp: 'ミーレスシリーズ', extra: true },
      { order: 36, slug: 'sephira', name_en: 'Sephira Weapons', name_jp: 'セフィラン・オールドウェポン', extra: true },
      { order: 37, slug: 'world', name_en: 'World Weapons', name_jp: 'ワールドシリーズ', extra: true, has_awakening: true },
      { order: 38, slug: 'replica', name_en: 'Replicas', name_jp: '複製品' },
      { order: 39, slug: 'rusted', name_en: 'Rusted Weapons', name_jp: '朽ち果てた武器' },
      { order: 40, slug: 'relic', name_en: 'Relics', name_jp: '依代' },
      { order: 41, slug: 'eternal-splendor', name_en: 'Weapons of Eternal Splendor', name_jp: '十天光輝' },
      { order: 42, slug: 'vyrmament', name_en: 'Vyrmament', name_jp: 'オイラは' },
      { order: 43, slug: 'collab', name_en: 'Collab', name_jp: 'コラボ武器' },
      { order: 44, slug: 'event', name_en: 'Event', name_jp: 'イベント武器' }
    ]

    puts "Creating weapon series records..."
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
      puts "  #{ws.slug}: #{ws.name_en}"
    end

    puts "\nCreated #{WeaponSeries.count} weapon series records"
  end

  def down
    WeaponSeries.delete_all
  end
end
