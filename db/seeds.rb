require 'csv'

def seed_weapons
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'weapons.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    w = Weapon.new
    w.name_en = row['name_en']
    w.name_jp = row['name_jp']
    w.granblue_id = row['granblue_id']
    w.rarity = row['rarity']
    w.element = row['element']
    w.proficiency = row['proficiency']
    w.series = row['series']
    w.flb = row['flb']
    w.ulb = row['ulb']
    w.extra = row['extra']
    w.ax = row['ax']
    w.awakening = row['awakening']
    w.limit = row['limit']
    w.max_level = row['max_level']
    w.max_skill_level = row['max_skill_level']
    w.min_hp = row['min_hp']
    w.max_hp = row['max_hp']
    w.max_hp_flb = row['max_hp_flb']
    w.max_hp_ulb = row['max_hp_ulb']
    w.min_atk = row['min_hp']
    w.max_atk = row['max_hp']
    w.max_atk_flb = row['max_hp_flb']
    w.max_atk_ulb = row['max_hp_ulb']
    w.save
  end

  puts "There are now #{Weapon.count} rows in the weapons table."
end

def seed_summons
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'summons.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    s = Summon.new
    s.name_en = row['name_en']
    s.name_jp = row['name_jp']
    s.granblue_id = row['granblue_id']
    s.rarity = row['rarity']
    s.element = row['element']
    s.flb = row['flb']
    s.ulb = row['ulb']
    s.subaura = row['subaura']
    s.limit = row['limit']
    s.max_level = row['max_level']
    s.min_hp = row['min_hp']
    s.max_hp = row['max_hp']
    s.max_hp_flb = row['max_hp_flb']
    s.max_hp_ulb = row['max_hp_ulb']
    s.min_atk = row['min_hp']
    s.max_atk = row['max_hp']
    s.max_atk_flb = row['max_hp_flb']
    s.max_atk_ulb = row['max_hp_ulb']
    s.save
  end

  puts "There are now #{Summon.count} rows in the summons table."
end

def seed_characters
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'characters.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    c = Character.new
    c.name_en = row['name_en']
    c.name_jp = row['name_jp']
    c.granblue_id = row['granblue_id']
    c.character_id = row['character_id']
    c.rarity = row['rarity']
    c.element = row['element']
    c.proficiency1 = row['proficiency1']
    c.proficiency2 = row['proficiency2']
    c.gender = row['gender']
    c.race1 = row['race1']
    c.race2 = row['race2']
    c.flb = row['flb']
    c.ulb = row['ulb']
    c.max_level = row['max_level']
    c.min_hp = row['min_hp']
    c.max_hp = row['max_hp']
    c.max_hp_flb = row['max_hp_flb']
    c.max_hp_ulb = row['max_hp_ulb']
    c.min_atk = row['min_hp']
    c.max_atk = row['max_hp']
    c.max_atk_flb = row['max_hp_flb']
    c.max_atk_ulb = row['max_hp_ulb']
    c.base_da = row['base_da']
    c.base_ta = row['base_ta']
    c.ougi_ratio = row['ougi_ratio']
    c.ougi_ratio_flb = row['ougi_ratio_flb']
    c.special = row['special']
    c.save
  end

  puts "There are now #{Character.count} rows in the characters table."
end

def seed_jobs
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'jobs.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    j = Job.new
    j.id = row['id']
    j.name_en = row['name_en']
    j.name_jp = row['name_jp']
    j.proficiency1 = row['proficiency1']
    j.proficiency2 = row['proficiency2']
    j.row = row['row']
    j.ml = row['ml']
    j.order = row['order']
    j.base_job_id = row['base_job_id']
    j.save
  end
end

def seed_job_skills
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'job_skills.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    j = JobSkill.new
    j.job_id = row['job_id']
    j.name_en = row['name_en']
    j.name_jp = row['name_jp']
    j.slug = row['slug']
    j.color = row['color']
    j.main = row['main']
    j.sub = row['sub']
    j.emp = row['emp']
    j.base = row['base']
    j.order = row['order']
    j.save
  end
end

def seed_weapon_keys
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'weapon_keys.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    k = WeaponKey.new
    k.name_en = row['name_en']
    k.name_jp = row['name_jp']
    k.series = row['series']
    k.slot = row['slot']
    k.group = row['group']
    k.order = row['order']
    k.slug = row['slug']
    k.save
  end
end

def seed_all
  seed_weapons
  seed_summons
  seed_characters
  seed_jobs
  seed_job_skills
end

seed_all
