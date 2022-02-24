object @party

attributes :id, :user_id, :name, :description, :shortcode

node :raid do |p|
    partial('raids/base', :object => p.raid)
end

node :is_extra do |p|
    p.extra
end

node :weapons do |p|
    partial('grid_weapons/base', :object => p.weapons)
end
