attributes :id,
    :party_id,
    :mainhand,
    :position

node :weapon do |w|
    partial("weapons/base", :object => w.weapon)
end