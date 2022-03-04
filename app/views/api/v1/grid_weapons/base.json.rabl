attributes :id,
    :party_id,
    :mainhand,
    :position,
    :uncap_level,
    :element

node :object do |w|
    partial("weapons/base", :object => w.weapon)
end

node :weapon_keys, :if => lambda { |w| [2, 3, 17, 22].include?(w.weapon.series) } do |w|
    partial("weapon_keys/base", :object => w.weapon_keys)
end

node :ax, :if => lambda { |w| w.weapon.ax > 0 } do |w|
    [
        {
            :modifier => w.ax_modifier1,
            :strength => w.ax_strength1
        },
        {
            :modifier => w.ax_modifier2,
            :strength => w.ax_strength2
        }
    ]
end