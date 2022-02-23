attributes :id,
    :party_id,
    :mainhand,
    :position,
    :uncap_level

node :object do |w|
    partial("weapons/base", :object => w.weapon)
end