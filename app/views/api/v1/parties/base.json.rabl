object :party

attributes :id, :user_id, :shortcode

node :weapons do |p|
    partial('grid_weapons/base', :object => p.weapons)
end

node :summons do |p|
    partial('grid_summons/base', :object => p.summons)
end
