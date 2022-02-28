object :party

attributes :id, :name, :description, :element, :favorited, :shortcode, :created_at, :updated_at

node :extra do |p|
    p.extra
end

node :user do |p|
    partial('users/base', :object => p.user)
end

node :raid do |p|
    partial('raids/base', :object => p.raid)
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
