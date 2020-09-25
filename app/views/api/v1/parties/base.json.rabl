object :party

attributes :id, :user_id, :shortcode

node :grid do |p|
    partial('grid_weapons/base', :object => p.weapons)
end
