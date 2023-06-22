require 'csv'

# Awakening

def seed_awakenings
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'awakenings.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    a = Awakening.new
    a.id = row['id']
    a.name_en = row['name_en']
    a.name_jp = row['name_jp']
    a.slug = row['slug']
    a.object_type = row['object_type']
    a.save
  end

  puts "There are now #{Awakening.count} awakenings in the database"
end

# Weapons

def seed_weapons
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'weapons.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    w = Weapon.new
    w.id = row['id']
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
    w.ax_type = row['ax_type']
    w.limit = row['limit']
    w.max_level = row['max_level']
    w.max_skill_level = row['max_skill_level']
    w.max_awakening_level = row['max_awakening_level']
    w.min_hp = row['min_hp']
    w.max_hp = row['max_hp']
    w.max_hp_flb = row['max_hp_flb']
    w.max_hp_ulb = row['max_hp_ulb']
    w.min_atk = row['min_hp']
    w.max_atk = row['max_hp']
    w.max_atk_flb = row['max_hp_flb']
    w.max_atk_ulb = row['max_hp_ulb']
    w.recruits_id = row['recruits_id']
    w.save
  end

  puts "There are now #{Weapon.count} rows in the weapons table."
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

  puts "There are now #{WeaponKey.count} rows in the weapon keys table."
end

# Summons

def seed_summons
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'summons.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    s = Summon.new
    s.id = row['id']
    s.name_en = row['name_en']
    s.name_jp = row['name_jp']
    s.granblue_id = row['granblue_id']
    s.rarity = row['rarity']
    s.element = row['element']
    s.series = row['series']
    s.flb = row['flb']
    s.ulb = row['ulb']
    s.xlb = row['xlb']
    s.subaura = row['subaura']
    s.limit = row['limit']
    s.max_level = row['max_level']
    s.min_hp = row['min_hp']
    s.max_hp = row['max_hp']
    s.max_hp_flb = row['max_hp_flb']
    s.max_hp_ulb = row['max_hp_ulb']
    s.max_hp_xlb = row['max_hp_xlb']
    s.min_atk = row['min_hp']
    s.max_atk = row['max_hp']
    s.max_atk_flb = row['max_hp_flb']
    s.max_atk_ulb = row['max_hp_ulb']
    s.max_atk_xlb = row['max_hp_xlb']
    s.save
  end

  puts "There are now #{Summon.count} rows in the summons table."
end

# Characters

def seed_characters
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'characters.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    c = Character.new
    c.id = row['id']
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

# Jobs

def seed_jobs
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'jobs.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    j = Job.new
    j.id = row['id']
    j.base_job_id = row['base_job_id']
    j.granblue_id = row['granblue_id']
    j.name_en = row['name_en']
    j.name_jp = row['name_jp']
    j.ultimate_mastery = row['ultimate_mastery']
    j.proficiency1 = row['proficiency1']
    j.proficiency2 = row['proficiency2']
    j.row = row['row']
    j.master_level = row['ml']
    j.order = row['order']
    j.accessory = row['accessory']
    j.accessory_type = row['accessory_type']
    j.save
  end

  puts "There are now #{Job.count} rows in the jobs table."

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

  puts "There are now #{JobSkill.count} rows in the job skills table."
end

def seed_job_accessories
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'job_accessories.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    j = JobAccessory.new
    j.id = row['id']
    j.job_id = row['job_id']
    j.name_en = row['name_en']
    j.name_jp = row['name_jp']
    j.granblue_id = row['granblue_id']
    j.rarity = row['rarity']
    j.release_date = row['release_date']
    j.accessory_type = row['accessory_type']
    j.save
  end

  puts "There are now #{JobAccessory.count} rows in the job accessories table."
end

# Raids

def seed_raids
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'raids.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    r = Raid.new
    r.id = row['id']
    r.group_id = row['group_id']
    r.name_en = row['name_en']
    r.name_jp = row['name_jp']
    r.element = row['element']
    r.rarity = row['rarity']
    r.slug = row['slug']
    r.save
  end

  puts "There are now #{Raid.count} rows in the raids table."
end

def seed_raid_groups
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'raid_groups.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    r = RaidGroup.new
    r.id = row['id']
    r.name_en = row['name_en']
    r.name_jp = row['name_jp']
    r.difficulty = row['difficulty']
    r.order = row['order']
    r.section = row['section']
    r.extra = row['extra']
    r.hl = row['hl']
    r.guidebooks = row['guidebooks']
    r.save
  end

  puts "There are now #{RaidGroup.count} rows in the raid groups table."
end

# Gacha

def seed_gacha
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'gacha.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    g = Gacha.new
    g.drawable_id = row['drawable_id']
    g.drawable_type = row['drawable_type']
    g.premium = row['premium']
    g.classic = row['classic']
    g.flash = row['flash']
    g.legend = row['legend']
    g.valentines = row['valentines']
    g.summer = row['summer']
    g.halloween = row['halloween']
    g.holiday = row['holiday']
    g.save
  end

  puts "There are now #{Gacha.count} rows in the gacha table."
end

# Guidebooks

def seed_guidebooks
  csv_text = File.read(Rails.root.join('lib', 'seeds', 'guidebooks.csv'))
  csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')
  csv.each do |row|
    g = Guidebook.new
    g.name_en = row['name_en']
    g.name_jp = row['name_jp']
    g.description_en = row['description_en']
    g.description_jp = row['description_jp']
    g.created_at = row['created_at']
    g.save
  end

  puts "There are now #{Guidebook.count} rows in the guidebooks table."
end

def seed_all
  seed_weapons
  seed_summons
  seed_characters
  seed_jobs
  seed_job_skills
end

seed_all
