# frozen_string_literal: true

class CreateCharacterSeriesRecords < ActiveRecord::Migration[8.0]
  def up
    character_series_data = [
      { order: 0, slug: 'standard', name_en: 'Standard', name_jp: 'スタンダード' },
      { order: 1, slug: 'grand', name_en: 'Grand', name_jp: 'リミテッド' },
      { order: 2, slug: 'zodiac', name_en: 'Zodiac', name_jp: '十二神将' },
      { order: 3, slug: 'promo', name_en: 'Promo', name_jp: 'プロモ' },
      { order: 4, slug: 'collab', name_en: 'Collab', name_jp: 'コラボ' },
      { order: 5, slug: 'eternal', name_en: 'Eternal', name_jp: '十天衆' },
      { order: 6, slug: 'evoker', name_en: 'Evoker', name_jp: '賢者' },
      { order: 7, slug: 'saint', name_en: 'Saint', name_jp: '六竜の使徒' },
      { order: 8, slug: 'fantasy', name_en: 'Fantasy', name_jp: 'ファンタジー' },
      { order: 9, slug: 'summer', name_en: 'Summer', name_jp: '水着' },
      { order: 10, slug: 'yukata', name_en: 'Yukata', name_jp: '浴衣' },
      { order: 11, slug: 'valentine', name_en: 'Valentine', name_jp: 'バレンタイン' },
      { order: 12, slug: 'halloween', name_en: 'Halloween', name_jp: 'ハロウィン' },
      { order: 13, slug: 'formal', name_en: 'Formal', name_jp: 'フォーマル' },
      { order: 14, slug: 'event', name_en: 'Event', name_jp: 'イベント' }
    ]

    puts 'Creating character series records...'
    character_series_data.each do |data|
      cs = CharacterSeries.find_or_initialize_by(slug: data[:slug])
      cs.assign_attributes(data)
      cs.save!
      puts "  #{cs.slug}: #{cs.name_en}"
    end

    puts "\nCreated #{CharacterSeries.count} character series records"
  end

  def down
    CharacterSeries.delete_all
  end
end
