# frozen_string_literal: true

class CreateSummonSeriesRecords < ActiveRecord::Migration[8.0]
  def up
    summon_series_data = [
      { order: 0, slug: 'providence', name_en: 'Providence Series', name_jp: 'プロヴィデンスシリーズ' },
      { order: 1, slug: 'genesis', name_en: 'Genesis Series', name_jp: 'ジェネシスシリーズ' },
      { order: 2, slug: 'magna', name_en: 'Magna Series', name_jp: 'マグナシリーズ' },
      { order: 3, slug: 'optimus', name_en: 'Optimus Series', name_jp: 'オプティマスシリーズ' },
      { order: 4, slug: 'demi-optimus', name_en: 'Demi Optimus Series', name_jp: 'オプティマス・ディヴィジョン' },
      { order: 5, slug: 'archangel', name_en: 'Archangel Series', name_jp: '天司シリーズ' },
      { order: 6, slug: 'arcarum', name_en: 'Arcarum Series', name_jp: 'アーカルムシリーズ' },
      { order: 7, slug: 'epic', name_en: 'Epic Series', name_jp: 'エピックシリーズ' },
      { order: 8, slug: 'carbuncle', name_en: 'Carbuncle Series', name_jp: 'カーバンクルシリーズ' },
      { order: 9, slug: 'dynamis', name_en: 'Dynamis Series', name_jp: 'デュナミスシリーズ' },
      { order: 10, slug: 'cryptid', name_en: 'Cryptid Series', name_jp: 'UMAシリーズ' },
      { order: 11, slug: 'six-dragons', name_en: 'Six Dragons', name_jp: '六竜シリーズ' },
      { order: 12, slug: 'bellum', name_en: 'Bellum Series', name_jp: 'ベルムシリーズ' },
      { order: 13, slug: 'crest', name_en: 'Crest Series', name_jp: 'クレストシリーズ' },
      { order: 14, slug: 'robur', name_en: 'Robur Series', name_jp: 'ロブルシリーズ' },
      { order: 15, slug: 'summer', name_en: 'Summer', name_jp: '水着' },
      { order: 16, slug: 'yukata', name_en: 'Yukata', name_jp: '浴衣' },
      { order: 17, slug: 'holiday', name_en: 'Holiday', name_jp: 'クリスマス' },
      { order: 18, slug: 'collab', name_en: 'Collab', name_jp: 'コラボ' }
    ]

    puts 'Creating summon series records...'
    summon_series_data.each do |data|
      ss = SummonSeries.find_or_initialize_by(slug: data[:slug])
      ss.assign_attributes(data)
      ss.save!
      puts "  #{ss.slug}: #{ss.name_en}"
    end

    puts "\nCreated #{SummonSeries.count} summon series records"
  end

  def down
    SummonSeries.delete_all
  end
end
