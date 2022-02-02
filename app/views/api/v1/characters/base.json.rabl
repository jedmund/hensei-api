object :summon

attributes :id,
    :granblue_id,
    :rarity,
    :element,
    :gender,
    :max_level,
    :special

node :name do |w|
    {
        :en => w.name_en,
        :jp => w.name_jp
    }
end

node :uncap do |w|
    {
        :flb => w.flb
    }
end

node :hp do |w|
    {
        :min_hp => w.min_hp,
        :max_hp => w.max_hp,
        :max_hp_flb => w.max_hp_flb
    }
end

node :atk do |w|
    {
        :min_atk => w.min_atk,
        :max_atk => w.max_atk,
        :max_atk_flb => w.max_atk_flb
    }
end

node :race do |w|
    [
        w.race1,
        w.race2
    ]
end

node :proficiency do |w|
    [
        w.proficiency1,
        w.proficiency2
    ]
end

node :data do |w|
    {
        :base_da => w.base_da,
        :base_ta => w.base_ta,
    }
end

node :ougi_ratio do |w|
    {
        :ougi_ratio => w.ougi_ratio,
        :ougi_ratio_flb => w.ougi_ratio_flb
    }
end