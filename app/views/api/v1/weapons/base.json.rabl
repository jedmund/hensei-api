object :weapon

attributes :id,
    :granblue_id,
    :element,
    :proficiency,
    :max_level,
    :max_skill_level

node :name do |w|
    {
        :en => w.name_en,
        :jp => w.name_jp
    }
end

node :uncap do |w|
    {
        :flb => w.flb,
        :ulb => w.ulb
    }
end

node :hp do |w|
    {
        :min_hp => w.min_hp,
        :max_hp => w.max_hp,
        :max_hp_flb => w.max_hp_flb,
        :max_hp_ulb => w.max_hp_ulb
    }
end

node :atk do |w|
    {
        :min_atk => w.min_atk,
        :max_atk => w.max_atk,
        :max_atk_flb => w.max_atk_flb,
        :max_atk_ulb => w.max_atk_ulb
    }
end