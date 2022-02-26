object :raid

attributes :id, :level, :group, :element

node :name do |r|
    {
        :en => r.name_en,
        :jp => r.name_jp
    }
end