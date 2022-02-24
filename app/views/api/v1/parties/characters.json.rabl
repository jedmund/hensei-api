object @party

attributes :id, :user_id, :name, :description, :shortcode

node :raid do |p|
    partial('raids/base', :object => p.raid)
end

node :characters do |p|
    partial('grid_characters/base', :object => p.characters)
end
