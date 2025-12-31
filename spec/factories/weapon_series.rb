FactoryBot.define do
  factory :weapon_series do
    sequence(:name_en) { |n| "Test Series #{n}" }
    sequence(:name_jp) { |n| "テストシリーズ#{n}" }
    sequence(:slug) { |n| "test-series-#{n}" }
    sequence(:order) { |n| n + 100 }

    extra { false }
    element_changeable { false }
    has_weapon_keys { false }
    has_awakening { false }
    augment_type { :none }

    trait :gacha do
      slug { 'gacha' }
      name_en { 'Gacha' }
      name_jp { 'ガチャ' }
      order { 99 }
    end

    trait :opus do
      slug { 'dark-opus' }
      name_en { 'Dark Opus' }
      name_jp { 'オプス' }
      order { 3 }
      has_weapon_keys { true }
      has_awakening { true }
    end

    trait :draconic do
      slug { 'draconic' }
      name_en { 'Draconic' }
      name_jp { 'ドラゴニック' }
      order { 27 }
      has_awakening { true }
    end

    trait :draconic_providence do
      slug { 'draconic-providence' }
      name_en { 'Draconic Providence' }
      name_jp { 'ドラゴニック・プロビデンス' }
      order { 40 }
      has_awakening { true }
    end

    trait :revenant do
      slug { 'revenant' }
      name_en { 'Revenant' }
      name_jp { '天星器' }
      order { 4 }
      element_changeable { true }
    end

    trait :ultima do
      slug { 'ultima' }
      name_en { 'Ultima' }
      name_jp { 'オメガ' }
      order { 13 }
      element_changeable { true }
    end

    trait :superlative do
      slug { 'superlative' }
      name_en { 'Superlative' }
      name_jp { '超越' }
      order { 17 }
      element_changeable { true }
      extra { true }
      has_weapon_keys { true }
    end

    trait :grand do
      slug { 'grand' }
      name_en { 'Grand' }
      name_jp { 'リミテッド' }
      order { 2 }
      has_weapon_keys { true }
    end

    trait :xeno do
      slug { 'xeno' }
      name_en { 'Xeno' }
      name_jp { 'ゼノ' }
      order { 11 }
      extra { true }
    end

    trait :extra_allowed do
      extra { true }
    end

    trait :element_changeable do
      element_changeable { true }
    end

    trait :with_weapon_keys do
      has_weapon_keys { true }
    end

    trait :with_ax_skills do
      augment_type { :ax }
    end

    trait :with_befoulments do
      augment_type { :befoulment }
    end

    trait :odiant do
      slug { 'odiant' }
      name_en { 'Odiant' }
      name_jp { '禁禍武器' }
      order { 50 }
      augment_type { :befoulment }
    end
  end
end
