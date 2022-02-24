object :raid

attributes :id, :level, :group

node :name do |r|
    {
        :en => r.name_en,
        :jp => r.name_jp
    }
end