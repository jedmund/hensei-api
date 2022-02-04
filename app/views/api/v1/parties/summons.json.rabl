object @party

attributes :id, :user_id, :shortcode

node :summons do |p|
    partial('grid_summons/base', :object => p.summons)
end
