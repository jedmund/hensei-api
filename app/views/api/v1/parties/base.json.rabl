object :party

attributes :id, :shortcode

node :grid do |p|
    partial('grid_weapons/base', :object => p.weapons)
end
