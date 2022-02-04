object @party

attributes :id, :user_id, :shortcode

node :is_extra do |p|
    p.extra
end

node :weapons do |p|
    partial('grid_weapons/base', :object => p.weapons)
end
