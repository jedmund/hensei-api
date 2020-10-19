attributes :id,
    :party_id,
    :main,
    :friend,
    :position

node :summon do |s|
    partial('summons/base', :object => s.summon)
end