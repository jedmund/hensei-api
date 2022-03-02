object :weapon_key

attributes :id, :series, :slot, :group

node :name do |k|
    {
        :en => k.name_en,
        :jp => k.name_jp
    }
end