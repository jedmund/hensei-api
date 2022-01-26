object :party

attributes :id, :user_id, :shortcode

node :is_extra do |p|
    p.extra
end

node :characters do |p|
    partial('grid_characters/base', :object => p.characters)
end

node :weapons do |p|
    partial('grid_weapons/base', :object => p.weapons)
end

node :summons do |p|
    partial('grid_summons/base', :object => p.summons)
end
