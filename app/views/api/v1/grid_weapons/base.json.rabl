attributes :id,
    :party_id,
    :mainhand,
    :position,
    :uncap_level

node :weapon do |w|
    partial("weapons/base", :object => w.weapon)
end