attributes :id,
    :party_id,
    :position

node :character do |c|
    partial("characters/base", :object => c.character)
end