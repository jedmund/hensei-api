attributes :id,
    :party_id,
    :position,
    :uncap_level,
    :perpetuity

node :object do |c|
    partial("characters/base", :object => c.character)
end