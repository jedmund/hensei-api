object @party

attributes :id, :name, :description, :shortcode, :favorited, :created_at, :updated_at

node :user do |p|
    partial('users/base', :object => p.user)
end

node :raid do |p|
    partial('raids/base', :object => p.raid)
end

node :summons do |p|
    partial('grid_summons/base', :object => p.summons)
end
