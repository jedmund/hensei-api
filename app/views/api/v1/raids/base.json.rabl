object :raid

attributes :id, :slug, :level, :group, :element

node :name do |r|
    {
        :en => r.name_en,
        :ja => r.name_jp
    }
end