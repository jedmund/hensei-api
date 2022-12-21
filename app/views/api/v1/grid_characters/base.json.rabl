attributes :id,
    :party_id,
    :position,
    :uncap_level,
    :perpetuity,

node :object do |c|
    partial("characters/base", :object => c.character)
end

node :awakening do |c|
    {
        :type => c.awakening_type,
        :level => c.awakening_level
    }
end
