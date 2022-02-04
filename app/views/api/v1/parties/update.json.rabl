object @party

attributes :id, :user_id, :shortcode

node :is_extra do |p|
    p.extra
end