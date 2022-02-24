object @party

attributes :id, :user_id, :name, :description, :shortcode

node :raid do |p|
    partial('raids/base', :object => p.raid)
end

node :summons do |p|
    partial('grid_summons/base', :object => p.summons)
end
