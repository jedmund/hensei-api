collection @skills, object_root: false

attributes :id, :job, :slug, :color, :main, :base, :sub, :emp, :order

node :name do |w|
  {
      :en => w.name_en,
      :ja => w.name_jp
  }
end

