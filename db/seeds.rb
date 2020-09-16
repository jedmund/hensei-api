require 'csv'

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