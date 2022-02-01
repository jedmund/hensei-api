attributes :id,
    :party_id,
    :position,
    :uncap_level

node :character do |c|
    partial("characters/base", :object => c.character)
end