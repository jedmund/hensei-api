object :party

attributes :id,
           :name,
           :description,
           :element,
           :favorited,
           :shortcode,
           :created_at,
           :updated_at

node :extra do |p|
  p.extra
end

node :user do |p|
  partial("users/base", object: p.user)
end

node :raid do |p|
  partial("raids/base", object: p.raid)
end

node :job do |p|
  partial("jobs/base", object: p.job)
end

node :job_skills do |p|
  {
    "0" => partial("job_skills/base", object: p.skill0),
    "1" => partial("job_skills/base", object: p.skill1),
    "2" => partial("job_skills/base", object: p.skill2),
    "3" => partial("job_skills/base", object: p.skill3),
  }
end

node :characters do |p|
  partial("grid_characters/base", object: p.characters)
end

node :weapons do |p|
  partial("grid_weapons/base", object: p.weapons)
end

node :summons do |p|
  partial("grid_summons/base", object: p.summons)
end
