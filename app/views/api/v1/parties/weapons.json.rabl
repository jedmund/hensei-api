object @party

attributes :id, :name, :description, :shortcode

node :user do |p|
    partial('users/base', :object => p.user)
end

node :raid do |p|
    partial('raids/base', :object => p.raid)
end

node :is_extra do |p|
    p.extra
end

node :weapons do |p|
    partial('grid_weapons/base', :object => p.weapons)
end
