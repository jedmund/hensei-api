object :job

attributes :id, :row, :ml, :order

node :name do |j|
    {
        :en => j.name_en,
        :ja => j.name_jp
    }
end

node :proficiency do |j|
    [
        j.proficiency1,
        j.proficiency2
    ]
end