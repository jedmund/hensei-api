object @party

attributes :id, :user_id, :shortcode

node :is_extra do |p|
  p.extra
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
