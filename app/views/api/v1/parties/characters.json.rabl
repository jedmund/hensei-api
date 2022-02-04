object @party

attributes :id, :user_id, :shortcode

node :characters do |p|
    partial('grid_characters/base', :object => p.characters)
end
