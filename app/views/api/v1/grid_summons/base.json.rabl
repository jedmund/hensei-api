attributes :id,
    :party_id,
    :main,
    :friend,
    :position,
    :uncap_level

node :object do |s|
    partial('summons/base', :object => s.summon)
end