attributes :id,
    :party_id,
    :main,
    :friend,
    :position

node :summon do |w|
    partial('summons/base', :object => w.summon)
end