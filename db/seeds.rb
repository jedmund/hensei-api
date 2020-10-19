require 'csv'

def seed_weapons
    csv_text = File.read(Rails.root.join('lib', 'seeds', 'weapons.csv'))
    csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
    csv.each do |row|
        w = Weapon.new
        w.name_en =         row['name_en']
        w.name_jp =         row['name_jp']
        w.granblue_id =     row['granblue_id']
        w.rarity =          row['rarity']
        w.element =         row['element']
        w.proficiency =     row['proficiency']
        w.series =          row['series']
        w.flb =             row['flb']
        w.ulb =             row['ulb']
        w.max_level =       row['max_level']
        w.max_skill_level = row['max_skill_level']
        w.min_hp =          row['min_hp']
        w.max_hp =          row['max_hp']
        w.max_hp_flb =      row['max_hp_flb']
        w.max_hp_ulb =      row['max_hp_ulb']
        w.min_atk =         row['min_hp']
        w.max_atk =         row['max_hp']
        w.max_atk_flb =     row['max_hp_flb']
        w.max_atk_ulb =     row['max_hp_ulb']
        w.save
    end

    puts "There are now #{Weapon.count} rows in the weapons table."
end

def seed_summons
    csv_text = File.read(Rails.root.join('lib', 'seeds', 'summons.csv'))
    csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
    csv.each do |row|
        s = Summon.new
        s.name_en =         row['name_en']
        s.name_jp =         row['name_jp']
        s.granblue_id =     row['granblue_id']
        s.rarity =          row['rarity']
        s.element =         row['element']
        s.flb =             row['flb']
        s.ulb =             row['ulb']
        s.max_level =       row['max_level']
        s.min_hp =          row['min_hp']
        s.max_hp =          row['max_hp']
        s.max_hp_flb =      row['max_hp_flb']
        s.max_hp_ulb =      row['max_hp_ulb']
        s.min_atk =         row['min_hp']
        s.max_atk =         row['max_hp']
        s.max_atk_flb =     row['max_hp_flb']
        s.max_atk_ulb =     row['max_hp_ulb']
        s.save
    end

    puts "There are now #{Summon.count} rows in the summons table."
end

def seed_characters
    csv_text = File.read(Rails.root.join('lib', 'seeds', 'characters.csv'))
    csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
    csv.each do |row|
        c = Character.new
        c.name_en =         row['name_en']
        c.name_jp =         row['name_jp']
        c.granblue_id =     row['granblue_id']
        c.rarity =          row['rarity']
        c.element =         row['element']
        c.proficiency1 =    row['proficiency1']
        c.proficiency2 =    row['proficiency2']
        c.gender =          row['gender']
        c.race1 =           row['race1']
        c.race2 =           row['race2']
        c.flb =             row['flb']
        c.max_level =       row['max_level']
        c.min_hp =          row['min_hp']
        c.max_hp =          row['max_hp']
        c.max_hp_flb =      row['max_hp_flb']
        c.min_atk =         row['min_hp']
        c.max_atk =         row['max_hp']
        c.max_atk_flb =     row['max_hp_flb']
        c.base_da =         row['base_da']
        c.base_ta =         row['base_ta']
        c.ougi_ratio =      row['ougi_ratio']
        c.ougi_ratio_flb =  row['ougi_ratio_flb']
        c.save
    end

    puts "There are now #{Character.count} rows in the characters table."
end

seed_weapons()
seed_summons()
seed_characters()