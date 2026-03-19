class SeedBullets < ActiveRecord::Migration[8.0]
  def up
    bullets = [
      { granblue_id: '10101', name_en: 'Iron Bullet', name_jp: 'アイアンバレット', slug: 'iron-bullet', bullet_type: 1, atk: 90, hits_all: false, effect_en: nil, order: 1 },
      { granblue_id: '10102', name_en: 'Iron Bullet II', name_jp: 'アイアンバレットII', slug: 'iron-bullet-ii', bullet_type: 1, atk: 100, hits_all: false, effect_en: nil, order: 2 },
      { granblue_id: '10103', name_en: 'Iron Bullet III', name_jp: 'アイアンバレットIII', slug: 'iron-bullet-iii', bullet_type: 1, atk: 110, hits_all: false, effect_en: nil, order: 3 },
      { granblue_id: '10104', name_en: 'Iron Bullet IV', name_jp: 'アイアンバレットIV', slug: 'iron-bullet-iv', bullet_type: 1, atk: 130, hits_all: false, effect_en: nil, order: 4 },
      { granblue_id: '10105', name_en: 'Iron Bullet V', name_jp: 'アイアンバレットV', slug: 'iron-bullet-v', bullet_type: 1, atk: 150, hits_all: false, effect_en: nil, order: 5 },
      { granblue_id: '10201', name_en: 'Rapid Bullet', name_jp: 'ライトバレット', slug: 'rapid-bullet', bullet_type: 1, atk: 60, hits_all: false, effect_en: 'Chance to gain Double Attack Rate Boosted (Stackable/Old Icon).', order: 6 },
      { granblue_id: '10202', name_en: 'Rapid Bullet II', name_jp: 'ライトバレットII', slug: 'rapid-bullet-ii', bullet_type: 1, atk: 80, hits_all: false, effect_en: 'Chance to gain Double Attack Rate Boosted (Stackable/Old Icon).', order: 7 },
      { granblue_id: '10203', name_en: 'Rapid Bullet III', name_jp: 'ライトバレットIII', slug: 'rapid-bullet-iii', bullet_type: 1, atk: 80, hits_all: false, effect_en: 'Chance to gain Double Attack Rate Boosted (Stackable/Old Icon) and Triple Attack Rate Boosted (Stackable/Old Icon).', order: 8 },
      { granblue_id: '10204', name_en: 'Rapid Bullet IV', name_jp: 'ライトバレットIV', slug: 'rapid-bullet-iv', bullet_type: 1, atk: 80, hits_all: false, effect_en: '~50 chance to gain Double Attack Rate Boosted (Stackable/Old Icon). / ~50 chance to gain Triple Attack Rate Boosted (Stackable/Old Icon).', order: 9 },
      { granblue_id: '10301', name_en: 'Flame Bullet', name_jp: 'フレイムバレット', slug: 'flame-bullet', bullet_type: 1, atk: 90, hits_all: false, effect_en: 'Chance to land Burn effect to a foe', order: 10 },
      { granblue_id: '10401', name_en: 'Poison Bullet', name_jp: 'ポイズンバレット', slug: 'poison-bullet', bullet_type: 1, atk: 90, hits_all: false, effect_en: 'Chance to land Poison effect to a foe', order: 11 },
      { granblue_id: '10501', name_en: 'Sleep Bullet', name_jp: 'スリープバレット', slug: 'sleep-bullet', bullet_type: 1, atk: 70, hits_all: false, effect_en: 'Chance to land Sleep effect to a foe', order: 12 },
      { granblue_id: '10601', name_en: 'Shield Bullet', name_jp: 'バリアシード', slug: 'shield-bullet', bullet_type: 1, atk: 50, hits_all: false, effect_en: 'Chance to gain Shield.', order: 13 },
      { granblue_id: '10701', name_en: 'Charm Bullet', name_jp: 'チャームバレット', slug: 'charm-bullet', bullet_type: 1, atk: 70, hits_all: false, effect_en: 'Chance to inflict Charm on a foe.', order: 14 },
      { granblue_id: '10801', name_en: 'Paralyze Bullet', name_jp: 'パラライズバレット', slug: 'paralyze-bullet', bullet_type: 1, atk: 80, hits_all: false, effect_en: '~25% chance to inflict Paralyzed 1 on a foe.', order: 15 },
      { granblue_id: '10901', name_en: 'Healing Bullet', name_jp: 'ヒールバレット', slug: 'healing-bullet', bullet_type: 1, atk: 80, hits_all: false, effect_en: 'All allies gain Refresh.', order: 16 },
      { granblue_id: '11001', name_en: 'Blazing Bullet', name_jp: 'ブレイズバレット', slug: 'blazing-bullet', bullet_type: 1, atk: 100, hits_all: false, effect_en: 'Chance to raise foe\'s Singed lvl by 1 (Max: 10).', order: 17 },
      { granblue_id: '11101', name_en: 'Toxic Bullet', name_jp: 'トキシックバレット', slug: 'toxic-bullet', bullet_type: 1, atk: 100, hits_all: false, effect_en: 'Chance to raise foe\'s Toxicosis lvl by 1 (Max: 10).', order: 18 },
      { granblue_id: '11201', name_en: 'Thundering Bullet', name_jp: 'サンダーバレットフリーズバレット', slug: 'thundering-bullet', bullet_type: 1, atk: 100, hits_all: false, effect_en: 'Chance to raise foe\'s Thunderstruck lvl by 1 (Max: 10).', order: 19 },
      { granblue_id: '11301', name_en: 'Freezing Bullet', name_jp: 'フリーズバレット', slug: 'freezing-bullet', bullet_type: 1, atk: 100, hits_all: false, effect_en: 'Chance to raise foe\'s Glaciate lvl by 1 (Max: 10).', order: 20 },
      { granblue_id: '20101', name_en: 'Full Metal Jacket', name_jp: 'フルメタルジャケット', slug: 'full-metal-jacket', bullet_type: 2, atk: 60, hits_all: false, effect_en: 'Chance to inflict DEF Lowered (Stackable).', order: 21 },
      { granblue_id: '20102', name_en: 'Full Metal Jacket II', name_jp: 'フルメタルジャケットII', slug: 'full-metal-jacket-ii', bullet_type: 2, atk: 80, hits_all: false, effect_en: 'Chance to inflict DEF Lowered (Stackable).', order: 22 },
      { granblue_id: '20103', name_en: 'Full Metal Jacket III', name_jp: 'フルメタルジャケットIII', slug: 'full-metal-jacket-iii', bullet_type: 2, atk: 100, hits_all: false, effect_en: 'Chance to inflict DEF Lowered (Stackable).', order: 23 },
      { granblue_id: '20104', name_en: 'Full Metal Jacket IV', name_jp: 'フルメタルジャケットIV', slug: 'full-metal-jacket-iv', bullet_type: 2, atk: 130, hits_all: false, effect_en: 'Chance to inflict DEF Lowered (Stackable).', order: 24 },
      { granblue_id: '20105', name_en: 'Full Metal Jacket V', name_jp: 'フルメタルジャケットV', slug: 'full-metal-jacket-v', bullet_type: 2, atk: 150, hits_all: false, effect_en: '95% chance to inflict DEF Lowered (Stackable).', order: 25 },
      { granblue_id: '20201', name_en: 'Exploder', name_jp: 'エクスプローダー', slug: 'exploder', bullet_type: 2, atk: 50, hits_all: false, effect_en: 'Chance to gain ATK Up (Stackable). / Chance to inflict DEF Lowered (Stackable) on foe.', order: 26 },
      { granblue_id: '20202', name_en: 'Exploder II', name_jp: 'エクスプローダーII', slug: 'exploder-ii', bullet_type: 2, atk: 75, hits_all: false, effect_en: 'Chance to gain ATK Up (Stackable). / Chance to inflict DEF Lowered (Stackable) on foe.', order: 27 },
      { granblue_id: '20203', name_en: 'Exploder III', name_jp: 'エクスプローダーIII', slug: 'exploder-iii', bullet_type: 2, atk: 105, hits_all: false, effect_en: 'Chance to gain ATK Up (Stackable). / Chance to inflict DEF Lowered (Stackable) on foe.', order: 28 },
      { granblue_id: '20301', name_en: 'Piercer', name_jp: 'アーマーピアシング', slug: 'piercer', bullet_type: 2, atk: 50, hits_all: false, effect_en: 'Chance to boost MC\'s critical hit rate and lower double attack rate (Stackable)', order: 29 },
      { granblue_id: '20302', name_en: 'Piercer II', name_jp: 'アーマーピアシングII', slug: 'piercer-ii', bullet_type: 2, atk: 70, hits_all: false, effect_en: 'Chance to boost MC\'s critical hit rate and lower double attack rate (Stackable)', order: 30 },
      { granblue_id: '20303', name_en: 'Piercer III', name_jp: 'アーマーピアシングIII', slug: 'piercer-iii', bullet_type: 2, atk: 70, hits_all: false, effect_en: 'Chance to boost MC\'s critical hit rate and lower double attack rate (Stackable)', order: 31 },
      { granblue_id: '20401', name_en: 'Silver Bullet', name_jp: 'シルバーバレット', slug: 'silver-bullet', bullet_type: 2, atk: 30, hits_all: false, effect_en: 'Chance to gain Chain Burst DMG Boosted (Stackable).', order: 32 },
      { granblue_id: '20402', name_en: 'Silver Bullet II', name_jp: 'シルバーバレットII', slug: 'silver-bullet-ii', bullet_type: 2, atk: 50, hits_all: false, effect_en: 'Chance to gain Chain Burst DMG Boosted (Stackable).', order: 33 },
      { granblue_id: '20403', name_en: 'Silver Bullet III', name_jp: 'シルバーバレットIII', slug: 'silver-bullet-iii', bullet_type: 2, atk: 80, hits_all: false, effect_en: 'Gain Chain Burst DMG Boosted (Stackable).', order: 34 },
      { granblue_id: '20501', name_en: 'Gold Bullet', name_jp: 'ゴールドバレット', slug: 'gold-bullet', bullet_type: 2, atk: 80, hits_all: false, effect_en: '~50% chance to gain C.A. DMG Boosted (Stackable).', order: 35 },
      { granblue_id: '20502', name_en: 'Gold Bullet II', name_jp: 'ゴールドバレットII', slug: 'gold-bullet-ii', bullet_type: 2, atk: 100, hits_all: false, effect_en: '~70% chance to gain C.A. DMG Boosted (Stackable). / Gain C.A. DMG Cap Boosted (Stackable).', order: 36 },
      { granblue_id: '20601', name_en: 'Expert Model: Paradise Lost', name_jp: 'エンドモデル:パラダイス･ロスト', slug: 'expert-model-paradise-lost', bullet_type: 2, atk: 200, hits_all: false, effect_en: 'Surpasses DMG cap by 30%', order: 37 },
      { granblue_id: '20701', name_en: 'Expert Model: Chaos Legion', name_jp: 'エンドモデル:ケイオスレギオン', slug: 'expert-model-chaos-legion', bullet_type: 2, atk: 200, hits_all: false, effect_en: 'Surpasses DMG cap by 30% / ~20% chance to inflict Bore (Foe) on foe', order: 38 },
      { granblue_id: '20801', name_en: 'Expert Model: Anagenesis', name_jp: 'エンドモデル:アナゲンネーシス', slug: 'expert-model-anagenesis', bullet_type: 2, atk: 250, hits_all: false, effect_en: 'Surpasses DMG cap by 30% / ~20% chance for all allies to gain a random Fruit of Treachery buff', order: 39 },
      { granblue_id: '20901', name_en: 'Expert Model: Genesis Nova', name_jp: 'エンドモデル:ジェネシス･ノヴァ', slug: 'expert-model-genesis-nova', bullet_type: 2, atk: 300, hits_all: false, effect_en: 'Surpasses DMG cap by 70% / 999,999 Plain DMG to all foes / Consume all bullets', order: 40 },
      { granblue_id: '21001', name_en: 'Expert Model: Rationale Exitium', name_jp: 'エンドモデル:ラツィオ・エグゼティウム', slug: 'expert-model-rationale-exitium', bullet_type: 2, atk: 400, hits_all: false, effect_en: 'Surpasses DMG cap by 50% / Ignore fire, water, earth, wind, light, and dark elemental resistances / 6-hit all-elemental DMG (Can only be loaded into 1 weapon once)', order: 41 },
      { granblue_id: '21101', name_en: 'Expert Model: Anti Vasileia', name_jp: 'エンドモデル:アンチ・バシレイア', slug: 'expert-model-anti-vasileia', bullet_type: 2, atk: 400, hits_all: false, effect_en: 'Supplement DMG dealt by 100% / Surpasses DMG cap by 70% (Can only be loaded into 1 weapon once / MC starts battle with Grand Finale Countdown (Bullet) 6 / Progress Countdown by 1 when this bullet is fired / 2-hit, 6,666,666 Plain DMG to a foe at end of turn when Countdown reaches 0)', order: 42 },
      { granblue_id: '30101', name_en: 'Shotshell', name_jp: 'シェルバレット', slug: 'shotshell', bullet_type: 3, atk: 35, hits_all: true, effect_en: nil, order: 43 },
      { granblue_id: '30102', name_en: 'Shotshell II', name_jp: 'シェルバレットII', slug: 'shotshell-ii', bullet_type: 3, atk: 50, hits_all: true, effect_en: nil, order: 44 },
      { granblue_id: '30103', name_en: 'Shotshell III', name_jp: 'シェルバレットIII', slug: 'shotshell-iii', bullet_type: 3, atk: 70, hits_all: true, effect_en: nil, order: 45 },
      { granblue_id: '30104', name_en: 'Shotshell IV', name_jp: 'シェルバレットIV', slug: 'shotshell-iv', bullet_type: 3, atk: 105, hits_all: true, effect_en: nil, order: 46 },
      { granblue_id: '30105', name_en: 'Shotshell V', name_jp: 'シェルバレットV', slug: 'shotshell-v', bullet_type: 3, atk: 120, hits_all: true, effect_en: nil, order: 47 },
      { granblue_id: '30201', name_en: 'Strike Shell', name_jp: 'アサルトシェル', slug: 'strike-shell', bullet_type: 3, atk: 90, hits_all: true, effect_en: 'Self-inflict DEF Lowered (Stackable / Unremovable).', order: 48 },
      { granblue_id: '30202', name_en: 'Strike Shell II', name_jp: 'アサルトシェルII', slug: 'strike-shell-ii', bullet_type: 3, atk: 135, hits_all: true, effect_en: 'Self-inflict DEF Lowered (Stackable / Unremovable).', order: 49 },
      { granblue_id: '30301', name_en: 'Fire Cylinder', name_jp: 'ヒートシリンダー', slug: 'fire-cylinder', bullet_type: 3, atk: 50, hits_all: true, effect_en: 'Chance to inflict Fire Lowered (Stackable) on all foes.', order: 50 },
      { granblue_id: '30302', name_en: 'Fire Cylinder II', name_jp: 'ヒートシリンダーII', slug: 'fire-cylinder-ii', bullet_type: 3, atk: 90, hits_all: true, effect_en: 'Chance to inflict Fire Lowered (Stackable) on all foes.', order: 51 },
      { granblue_id: '30401', name_en: 'Water Cylinder', name_jp: 'コールドシリンダー', slug: 'water-cylinder', bullet_type: 3, atk: 50, hits_all: true, effect_en: 'Chance to inflict Water Lowered (Stackable) on all foes.', order: 52 },
      { granblue_id: '30402', name_en: 'Water Cylinder II', name_jp: 'コールドシリンダーII', slug: 'water-cylinder-ii', bullet_type: 3, atk: 90, hits_all: true, effect_en: 'Chance to inflict Water Lowered (Stackable) on all foes.', order: 53 },
      { granblue_id: '30501', name_en: 'Earth Cylinder', name_jp: 'アースシリンダー', slug: 'earth-cylinder', bullet_type: 3, atk: 50, hits_all: true, effect_en: 'Chance to inflict Earth Lowered (Stackable) on all foes.', order: 54 },
      { granblue_id: '30502', name_en: 'Earth Cylinder II', name_jp: 'アースシリンダーII', slug: 'earth-cylinder-ii', bullet_type: 3, atk: 90, hits_all: true, effect_en: 'Chance to inflict Earth Lowered (Stackable) on all foes.', order: 55 },
      { granblue_id: '30601', name_en: 'Wind Cylinder', name_jp: 'ゲイルシリンダー', slug: 'wind-cylinder', bullet_type: 3, atk: 50, hits_all: true, effect_en: 'Chance to inflict Wind Lowered (Stackable) on all foes.', order: 56 },
      { granblue_id: '30602', name_en: 'Wind Cylinder II', name_jp: 'ゲイルシリンダーII', slug: 'wind-cylinder-ii', bullet_type: 3, atk: 90, hits_all: true, effect_en: 'Chance to inflict Wind Lowered (Stackable) on all foes.', order: 57 },
      { granblue_id: '30701', name_en: 'Light Cylinder', name_jp: 'サンダーシリンダー', slug: 'light-cylinder', bullet_type: 3, atk: 50, hits_all: true, effect_en: 'Chance to inflict Light Lowered (Stackable) on all foes.', order: 58 },
      { granblue_id: '30702', name_en: 'Light Cylinder II', name_jp: 'サンダーシリンダーII', slug: 'light-cylinder-ii', bullet_type: 3, atk: 90, hits_all: true, effect_en: 'Chance to inflict Light Lowered (Stackable) on all foes.', order: 59 },
      { granblue_id: '30801', name_en: 'Dark Cylinder', name_jp: 'ダークシリンダー', slug: 'dark-cylinder', bullet_type: 3, atk: 50, hits_all: true, effect_en: 'Chance to inflict Dark Lowered (Stackable) on all foes.', order: 60 },
      { granblue_id: '30802', name_en: 'Dark Cylinder II', name_jp: 'ダークシリンダーII', slug: 'dark-cylinder-ii', bullet_type: 3, atk: 90, hits_all: true, effect_en: 'Chance to inflict Dark Lowered (Stackable) on all foes.', order: 61 },
      { granblue_id: '30901', name_en: 'Guard Breaker', name_jp: 'アーマーブレイカー', slug: 'guard-breaker', bullet_type: 3, atk: 50, hits_all: true, effect_en: 'Chance to lower all foes\' DEF (Stackable)', order: 62 },
      { granblue_id: '30902', name_en: 'Guard Breaker II', name_jp: 'アーマーブレイカーII', slug: 'guard-breaker-ii', bullet_type: 3, atk: 75, hits_all: true, effect_en: 'Chance to lower all foes\' DEF (Stackable)', order: 63 },
      { granblue_id: '31001', name_en: 'Slug Shot', name_jp: 'スラッグショット', slug: 'slug-shot', bullet_type: 3, atk: 200, hits_all: false, effect_en: 'Hit to MC\'s double attack rate and DEF (Stackable)', order: 64 },
      { granblue_id: '31002', name_en: 'Slug Shot II', name_jp: 'スラッグショットII', slug: 'slug-shot-ii', bullet_type: 3, atk: 300, hits_all: false, effect_en: 'Hit to MC\'s double attack rate and DEF (Stackable)', order: 65 },
      { granblue_id: '31101', name_en: 'Sticky Shell', name_jp: 'スティッキーシェル', slug: 'sticky-shell', bullet_type: 3, atk: 50, hits_all: true, effect_en: 'Hit to all foes\' multiattack rate', order: 66 },
      { granblue_id: '31102', name_en: 'Sticky Shell II', name_jp: 'スティッキーシェルII', slug: 'sticky-shell-ii', bullet_type: 3, atk: 80, hits_all: true, effect_en: 'Inflict DA Down and TA Down on all foes.', order: 67 },
      { granblue_id: '31201', name_en: 'Chaser Shell', name_jp: 'チェイスシェル', slug: 'chaser-shell', bullet_type: 3, atk: 60, hits_all: true, effect_en: '~80% chance to gain Bonus DMG', order: 68 },
      { granblue_id: '31301', name_en: 'Enhancing Shell', name_jp: 'エンハンスシェル', slug: 'enhancing-shell', bullet_type: 3, atk: 90, hits_all: true, effect_en: '~50% chance for each ally to gain DMG Boosted.', order: 69 },
      { granblue_id: '31401', name_en: 'Catastrophe Cylinder', name_jp: 'カタストロフィシリンダー', slug: 'catastrophe-cylinder', bullet_type: 3, atk: 140, hits_all: true, effect_en: 'Chance to gain C.A. DMG Boosted (1 time) and C.A. DMG Cap Boosted (1 time).', order: 70 },
      { granblue_id: '31501', name_en: 'Akashic Cylinder', name_jp: 'アカシックシリンダー', slug: 'akashic-cylinder', bullet_type: 3, atk: 140, hits_all: true, effect_en: 'Chance to progress battle turn by 1', order: 71 },
      { granblue_id: '31601', name_en: 'Cosmos Cylinder', name_jp: 'コスモスシリンダー', slug: 'cosmos-cylinder', bullet_type: 3, atk: 140, hits_all: true, effect_en: 'Chance to gain Peacemaker\'s Wings.', order: 72 },
      { granblue_id: '31701', name_en: 'Expert Model: Apocalypse', name_jp: 'エンドモデル:アポカリプス', slug: 'expert-model-apocalypse', bullet_type: 3, atk: 200, hits_all: false, effect_en: 'Deals DMG to all foes / Surpasses DMG cap by 50% / 1 random buff and 1 random debuff to MC.', order: 73 },
      { granblue_id: '40101', name_en: 'Ifrit Point', name_jp: 'イフリートポイント', slug: 'ifrit-point', bullet_type: 4, atk: 80, hits_all: false, effect_en: 'Chance to gain Fire ATK Boosted (Stackable).', order: 74 },
      { granblue_id: '40102', name_en: 'Ifrit Point II', name_jp: 'イフリートポイントII', slug: 'ifrit-point-ii', bullet_type: 4, atk: 100, hits_all: false, effect_en: 'Chance to gain Fire ATK Boosted (Stackable).', order: 75 },
      { granblue_id: '40103', name_en: 'Ifrit Point III', name_jp: 'イフリートポイントIII', slug: 'ifrit-point-iii', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'Gain Fire ATK Boosted (Stackable).', order: 76 },
      { granblue_id: '40201', name_en: 'Cocytus Point', name_jp: 'コキュートスポイント', slug: 'cocytus-point', bullet_type: 4, atk: 80, hits_all: false, effect_en: 'Chance to gain Water ATK Boosted (Stackable).', order: 77 },
      { granblue_id: '40202', name_en: 'Cocytus Point II', name_jp: 'コキュートスポイントII', slug: 'cocytus-point-ii', bullet_type: 4, atk: 100, hits_all: false, effect_en: 'Chance to gain Water ATK Boosted (Stackable).', order: 78 },
      { granblue_id: '40203', name_en: 'Cocytus Point III', name_jp: 'コキュートスポイントIII', slug: 'cocytus-point-iii', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'Gain Water ATK Boosted (Stackable).', order: 79 },
      { granblue_id: '40301', name_en: 'Vohu Manah Point', name_jp: 'ウォフマナフポイント', slug: 'vohu-manah-point', bullet_type: 4, atk: 80, hits_all: false, effect_en: 'Chance to gain Earth ATK Boosted (Stackable).', order: 80 },
      { granblue_id: '40302', name_en: 'Vohu Manah Point II', name_jp: 'ウォフマナフポイントII', slug: 'vohu-manah-point-ii', bullet_type: 4, atk: 100, hits_all: false, effect_en: 'Chance to gain Earth ATK Boosted (Stackable).', order: 81 },
      { granblue_id: '40303', name_en: 'Vohu Manah Point III', name_jp: 'ウォフマナフポイントIII', slug: 'vohu-manah-point-iii', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'Gain Earth ATK Boosted (Stackable).', order: 82 },
      { granblue_id: '40401', name_en: 'Sagittarius Point', name_jp: 'サジタリウスポイント', slug: 'sagittarius-point', bullet_type: 4, atk: 80, hits_all: false, effect_en: 'Chance to gain Wind ATK Boosted (Stackable).', order: 83 },
      { granblue_id: '40402', name_en: 'Sagittarius Point II', name_jp: 'サジタリウスポイントII', slug: 'sagittarius-point-ii', bullet_type: 4, atk: 100, hits_all: false, effect_en: 'Chance to gain Wind ATK Boosted (Stackable).', order: 84 },
      { granblue_id: '40403', name_en: 'Sagittarius Point III', name_jp: 'サジタリウスポイントIII', slug: 'sagittarius-point-iii', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'Gain Wind ATK Boosted (Stackable).', order: 85 },
      { granblue_id: '40501', name_en: 'Corow Point', name_jp: 'コロゥポイント', slug: 'corow-point', bullet_type: 4, atk: 80, hits_all: false, effect_en: 'Chance to gain Light ATK Boosted (Stackable).', order: 86 },
      { granblue_id: '40502', name_en: 'Corow Point II', name_jp: 'コロゥポイントII', slug: 'corow-point-ii', bullet_type: 4, atk: 100, hits_all: false, effect_en: 'Chance to gain Light ATK Boosted (Stackable).', order: 87 },
      { granblue_id: '40503', name_en: 'Corow Point III', name_jp: 'コロゥポイントIII', slug: 'corow-point-iii', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'Gain Light ATK Boosted (Stackable).', order: 88 },
      { granblue_id: '40601', name_en: 'Diablo Point', name_jp: 'ディアボロスポイント', slug: 'diablo-point', bullet_type: 4, atk: 80, hits_all: false, effect_en: 'Chance to gain Dark ATK Boosted (Stackable).', order: 89 },
      { granblue_id: '40602', name_en: 'Diablo Point II', name_jp: 'ディアボロスポイントII', slug: 'diablo-point-ii', bullet_type: 4, atk: 100, hits_all: false, effect_en: 'Chance to gain Dark ATK Boosted (Stackable).', order: 90 },
      { granblue_id: '40603', name_en: 'Diablo Point III', name_jp: 'ディアボロスポイントIII', slug: 'diablo-point-iii', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'Gain Dark ATK Boosted (Stackable).', order: 91 },
      { granblue_id: '40701', name_en: 'Agni Point', name_jp: 'アグニスポイント', slug: 'agni-point', bullet_type: 4, atk: 65, hits_all: false, effect_en: 'Chance for each ally to gain Fire ATK Boosted (Stackable).', order: 92 },
      { granblue_id: '40702', name_en: 'Agni Point II', name_jp: 'アグニスポイントII', slug: 'agni-point-ii', bullet_type: 4, atk: 100, hits_all: false, effect_en: 'Chance for each ally to gain Fire ATK Boosted (Stackable).', order: 93 },
      { granblue_id: '40703', name_en: 'Agni Point III', name_jp: 'アグニスポイントIII', slug: 'agni-point-iii', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'All allies gain Fire ATK Boosted (Stackable).', order: 94 },
      { granblue_id: '40704', name_en: 'Agni Point IV', name_jp: 'アグニスポイントIV', slug: 'agni-point-iv', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'Deals 10% amplified DMG when at elemental advantage.', order: 95 },
      { granblue_id: '40801', name_en: 'Neptune Point', name_jp: 'ネプチューンポイント', slug: 'neptune-point', bullet_type: 4, atk: 65, hits_all: false, effect_en: 'Chance for each ally to gain Water ATK Boosted (Stackable).', order: 96 },
      { granblue_id: '40802', name_en: 'Neptune Point II', name_jp: 'ネプチューンポイントII', slug: 'neptune-point-ii', bullet_type: 4, atk: 100, hits_all: false, effect_en: 'Chance for each ally to gain Water ATK Boosted (Stackable).', order: 97 },
      { granblue_id: '40803', name_en: 'Neptune Point III', name_jp: 'ネプチューンポイントIII', slug: 'neptune-point-iii', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'All allies gain Water ATK Boosted (Stackable).', order: 98 },
      { granblue_id: '40804', name_en: 'Neptune Point IV', name_jp: 'ネプチューンポイントIV', slug: 'neptune-point-iv', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'Deals 10% amplified DMG when at elemental advantage.', order: 99 },
      { granblue_id: '40901', name_en: 'Titan Point', name_jp: 'ティターンポイント', slug: 'titan-point', bullet_type: 4, atk: 65, hits_all: false, effect_en: 'Chance for each ally to gain Earth ATK Boosted (Stackable).', order: 100 },
      { granblue_id: '40902', name_en: 'Titan Point II', name_jp: 'ティターンポイントII', slug: 'titan-point-ii', bullet_type: 4, atk: 100, hits_all: false, effect_en: 'Chance for each ally to gain Earth ATK Boosted (Stackable).', order: 101 },
      { granblue_id: '40903', name_en: 'Titan Point III', name_jp: 'ティターンポイントIII', slug: 'titan-point-iii', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'All allies gain Earth ATK Boosted (Stackable).', order: 102 },
      { granblue_id: '40904', name_en: 'Titan Point IV', name_jp: 'ティターンポイントIV', slug: 'titan-point-iv', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'Deals 10% amplified DMG when at elemental advantage.', order: 103 },
      { granblue_id: '41001', name_en: 'Zephyrus Point', name_jp: 'ゼピュロスポイント', slug: 'zephyrus-point', bullet_type: 4, atk: 65, hits_all: false, effect_en: 'Chance for each ally to gain Wind ATK Boosted (Stackable).', order: 104 },
      { granblue_id: '41002', name_en: 'Zephyrus Point II', name_jp: 'ゼピュロスポイントII', slug: 'zephyrus-point-ii', bullet_type: 4, atk: 100, hits_all: false, effect_en: 'Chance for each ally to gain Wind ATK Boosted (Stackable).', order: 105 },
      { granblue_id: '41003', name_en: 'Zephyrus Point III', name_jp: 'ゼピュロスポイントIII', slug: 'zephyrus-point-iii', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'All allies gain Wind ATK Boosted (Stackable).', order: 106 },
      { granblue_id: '41004', name_en: 'Zephyrus Point IV', name_jp: 'ゼピュロスポイントIV', slug: 'zephyrus-point-iv', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'Deals 10% amplified DMG when at elemental advantage.', order: 107 },
      { granblue_id: '41101', name_en: 'Zeus Point', name_jp: 'ゼウスポイント', slug: 'zeus-point', bullet_type: 4, atk: 65, hits_all: false, effect_en: 'Chance for all allies to gain Light ATK Boosted (Stackable).', order: 108 },
      { granblue_id: '41102', name_en: 'Zeus Point II', name_jp: 'ゼウスポイントII', slug: 'zeus-point-ii', bullet_type: 4, atk: 100, hits_all: false, effect_en: 'Chance for all allies to gain Light ATK Boosted (Stackable).', order: 109 },
      { granblue_id: '41103', name_en: 'Zeus Point III', name_jp: 'ゼウスポイントIII', slug: 'zeus-point-iii', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'All allies gain Light ATK Boosted (Stackable).', order: 110 },
      { granblue_id: '41104', name_en: 'Zeus Point IV', name_jp: 'ゼウスポイントIV', slug: 'zeus-point-iv', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'Deals 10% amplified DMG when at elemental advantage.', order: 111 },
      { granblue_id: '41201', name_en: 'Hades Point', name_jp: 'ハデスポイント', slug: 'hades-point', bullet_type: 4, atk: 65, hits_all: false, effect_en: 'Chance for all allies to gain Dark ATK Boosted (Stackable).', order: 112 },
      { granblue_id: '41202', name_en: 'Hades Point II', name_jp: 'ハデスポイントIV', slug: 'hades-point-ii', bullet_type: 4, atk: 100, hits_all: false, effect_en: 'Chance for all allies to gain Dark ATK Boosted (Stackable).', order: 113 },
      { granblue_id: '41203', name_en: 'Hades Point III', name_jp: 'ハデスポイントIII', slug: 'hades-point-iii', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'All allies gain Dark ATK Boosted (Stackable).', order: 114 },
      { granblue_id: '41204', name_en: 'Hades Point IV', name_jp: 'ハデスポイントIV', slug: 'hades-point-iv', bullet_type: 4, atk: 120, hits_all: false, effect_en: 'Deals 10% amplified DMG when at elemental advantage.', order: 115 },
      { granblue_id: '41301', name_en: 'Expert Model: Hexachromatic', name_jp: 'エンドモデル:ヘキサクロマティック', slug: 'expert-model-hexachromatic', bullet_type: 4, atk: 150, hits_all: false, effect_en: 'Surpasses DMG cap by 30% / 20% chance of 1 random Pearl to MC (\'\'\'While in effect:\'\'\' 30% boost to ATK / 20% Bonus elemental DMG upon normal attacks based on Pearl)', order: 116 },
    ]

    # Raw wiki data keyed by granblue_id
    wiki_data = {
      '10101' => '{{Bullet/Row
|id=10101
|name=Iron Bullet
|jpname=アイアンバレット
|desc=
|atk=90
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Iron Cluster,2
|material2=Blistering Ore,2
|material3=
|material4=
}}',
      '10102' => '{{Bullet/Row
|id=10102
|name=Iron Bullet II
|jpname=アイアンバレットII
|desc=
|atk=100
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Iron Cluster,5
|material2=Blistering Ore,5
|material3=Iron Bullet,1
|material4=
}}',
      '10103' => '{{Bullet/Row
|id=10103
|name=Iron Bullet III
|jpname=アイアンバレットIII
|desc=
|atk=110
|type=
|hit_all=
|bullet_casting=1
|emp=2
|release_date=
|material1=Iron Cluster,12
|material2=Blistering Ore,8
|material3=Iron Bullet II,2
|material4=Untamed Flame,5
}}',
      '10104' => '{{Bullet/Row
|id=10104
|name=Iron Bullet IV
|jpname=アイアンバレットIV
|desc=
|atk=130
|type=
|hit_all=
|bullet_casting=1
|emp=3
|release_date=
|material1=Iron Cluster,25
|material2=Blistering Ore,20
|material3=Iron Bullet III,5
|material4=Prosperity Flame,20
}}',
      '10105' => '{{Bullet/Row
|id=10105
|name=Iron Bullet V
|jpname=アイアンバレットV
|desc=
|atk=150
|type=
|hit_all=
|bullet_casting=2
|emp=1
|release_date=
|material1=Iron Cluster,40
|material2=Blistering Ore,30
|material3=Iron Bullet IV,3
|material4=Iron Bullet III,2
}}',
      '10201' => '{{Bullet/Row
|id=10201
|name=Rapid Bullet
|jpname=ライトバレット
|desc=Chance to gain {{status|Double Attack Rate Boosted (Stackable/Old Icon)|t=Indefinite}}.
|atk=60
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Iron Cluster,2
|material2=Prosperity Flame,2
|material3=Steel Liquid,3
|material4=
}}',
      '10202' => '{{Bullet/Row
|id=10202
|name=Rapid Bullet II
|jpname=ライトバレットII
|desc=Chance to gain {{status|Double Attack Rate Boosted (Stackable/Old Icon)|t=Indefinite}}.
|atk=80
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Iron Cluster,4
|material2=Prosperity Flame,4
|material3=Steel Liquid,7
|material4=Rapid Bullet,1
}}',
      '10203' => '{{Bullet/Row
|id=10203
|name=Rapid Bullet III
|jpname=ライトバレットIII
|desc=Chance to gain {{status|Double Attack Rate Boosted (Stackable/Old Icon)|t=Indefinite}} and {{status|Triple Attack Rate Boosted (Stackable/Old Icon)|t=Indefinite}}.
|atk=80
|type=
|hit_all=
|bullet_casting=1
|emp=2
|release_date=
|material1=Iron Cluster,20
|material2=Prosperity Flame,20
|material3=Steel Liquid,20
|material4=Rapid Bullet II,2
}}',
      '10204' => '{{Bullet/Row
|id=10204
|name=Rapid Bullet IV
|jpname=ライトバレットIV
|desc=~50 chance to gain {{status|Double Attack Rate Boosted (Stackable/Old Icon)|t=Indefinite|a=?%|am=40%}}.<br/>~50 chance to gain {{status|Triple Attack Rate Boosted (Stackable/Old Icon)|t=Indefinite|a=?%|am=30%}}.<ref name=\'ULTZZ_rapid_4\'>ULTZZ - Rapid Bullet IV, https://twitter.com/ULTZZ/status/1135153247784558592</ref><ref name="Kamigame">Kamigame, https://kamigame.jp/グラブル/ゲーム知識/バレットまとめ.html</ref>
|atk=80
|type=
|hit_all=
|bullet_casting=2
|emp=2
|release_date=
|material1=Iron Cluster,30
|material2=Prosperity Flame,30
|material3=Steel Liquid,25
|material4=Rapid Bullet III,2
}}',
      '10301' => '{{Bullet/Row
|id=10301
|name=Flame Bullet
|jpname=フレイムバレット
|desc=Chance to land Burn effect to a foe
|atk=90
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Iron Bullet,5
|material2=Fire Orb,10
|material3=Infernal Whorl,7
|material4=Prosperity Flame,5
}}',
      '10401' => '{{Bullet/Row
|id=10401
|name=Poison Bullet
|jpname=ポイズンバレット
|desc=Chance to land Poison effect to a foe
|atk=90
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Iron Bullet,5
|material2=Water Orb,10
|material3=Tidal Whorl,7
|material4=Prosperity Flame,5
}}',
      '10501' => '{{Bullet/Row
|id=10501
|name=Sleep Bullet
|jpname=スリープバレット
|desc=Chance to land Sleep effect to a foe
|atk=70
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Iron Bullet,5
|material2=Wind Orb,10
|material3=Tempest Whorl,7
|material4=Prosperity Flame,5
}}',
      '10601' => '{{Bullet/Row
|id=10601
|name=Shield Bullet
|jpname=バリアシード
|desc=Chance to gain {{Status|Shield|a=500|t=1.5T}}.
|atk=50
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Rapid Bullet II,3
|material2=Radiant Whorl,20
|material3=Hollow Soul,10
|material4=Prosperity Flame,10
}}',
      '10701' => '{{Bullet/Row
|id=10701
|name=Charm Bullet
|jpname=チャームバレット
|desc=Chance to inflict {{Status|Charm}} on a foe.
|atk=70
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Iron Bullet,5
|material2=Earth Orb,10
|material3=Seismic Whorl,7
|material4=Corroded Cartridge,2
}}',
      '10801' => '{{Bullet/Row
|id=10801
|name=Paralyze Bullet
|jpname=パラライズバレット
|desc=~25% chance to inflict {{Status|Paralyzed 1|t=0.5T}} on a foe.<ref name=\'ULTZZ_para\'>ULTZZ - Paralyze Bullet, https://twitter.com/ULTZZ/status/1138107390216163328</ref>
|atk=80
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Iron Bullet V,1
|material2=Rapid Bullet IV,1
|material3=Primeval Horn,2
|material4=Bastion Block,5
}}',
      '10901' => '{{Bullet/Row
|id=10901
|name=Healing Bullet
|jpname=ヒールバレット
|desc=All allies gain {{Status|Refresh|a=1000 HP|t=1.5T}}.
|atk=80
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Iron Bullet V,1
|material2=Rapid Bullet IV,1
|material3=Silver Centrum,2
|material4=Bastion Block,5
}}',
      '11001' => '{{Bullet/Row
|id=11001
|name=Blazing Bullet
|jpname=ブレイズバレット
|desc=Chance to raise foe\'s {{status|Singed|t=i}} lvl by 1 (Max: 10).
|atk=100
|type=
|hit_all=
|bullet_casting=
|emp=?
|release_date=
|material1=Iron Bullet II,1
|material2=Fire Urn,10
|material3=Rubeus Centrum,30
|material4=
}}',
      '11101' => '{{Bullet/Row
|id=11101
|name=Toxic Bullet
|jpname=トキシックバレット
|desc=Chance to raise foe\'s {{status|Toxicosis|t=i}} lvl by 1 (Max: 10).
|atk=100
|type=
|hit_all=
|bullet_casting=
|emp=?
|release_date=
|material1=Iron Bullet II,1
|material2=Water Urn,10
|material3=Indicus Centrum,30
|material4=
}}',
      '11201' => '{{Bullet/Row
|id=11201
|name=Thundering Bullet
|jpname=サンダーバレットフリーズバレット
|desc=Chance to raise foe\'s {{status|Thunderstruck|t=i}} lvl by 1 (Max: 10).
|atk=100
|type=
|hit_all=
|bullet_casting=
|emp=?
|release_date=
|material1=Iron Bullet II,1
|material2=Light Urn,10
|material3=Niveus Centrum,30
|material4=
}}',
      '11301' => '{{Bullet/Row
|id=11301
|name=Freezing Bullet
|jpname=フリーズバレット
|desc=Chance to raise foe\'s {{status|Glaciate|t=i}} lvl by 1 (Max: 10).
|atk=100
|type=
|hit_all=
|bullet_casting=
|emp=?
|release_date=
|material1=Iron Bullet II,1
|material2=Water Urn,10
|material3=Indicus Centrum,30
|material4=
}}',
      '20101' => '{{Bullet/Row
|id=20101
|name=Full Metal Jacket
|jpname=フルメタルジャケット
|desc=Chance to inflict {{status|DEF Lowered (Stackable)|t=180s}}.
|atk=60
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Iron Cluster,3
|material2=Sand Brick,3
|material3=Coarse Alluvium,7
|material4=Rumbling Orb,2
}}',
      '20102' => '{{Bullet/Row
|id=20102
|name=Full Metal Jacket II
|jpname=フルメタルジャケットII
|desc=Chance to inflict {{status|DEF Lowered (Stackable)|t=180s}}.
|atk=80
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Full Metal Jacket,1
|material2=Iron Cluster,7
|material3=Coarse Alluvium,10
|material4=Rumbling Orb,5
}}',
      '20103' => '{{Bullet/Row
|id=20103
|name=Full Metal Jacket III
|jpname=フルメタルジャケットIII
|desc=Chance to inflict {{status|DEF Lowered (Stackable)|t=180s}}.
|atk=100
|type=
|hit_all=
|bullet_casting=1
|emp=2
|release_date=
|material1=Full Metal Jacket II,2
|material2=Iron Cluster,12
|material3=Steel Liquid,10
|material4=Untamed Flame,12
}}',
      '20104' => '{{Bullet/Row
|id=20104
|name=Full Metal Jacket IV
|jpname=フルメタルジャケットIV
|desc=Chance to inflict {{status|DEF Lowered (Stackable)|t=180s}}.
|atk=130
|type=
|hit_all=
|bullet_casting=1
|emp=3
|release_date=
|material1=Full Metal Jacket III,5
|material2=Iron Cluster,25
|material3=Steel Liquid,20
|material4=Sand Brick,25
}}',
      '20105' => '{{Bullet/Row
|id=20105
|name=Full Metal Jacket V
|jpname=フルメタルジャケットV
|desc={{Verify|95%}} chance to inflict {{status|DEF Lowered (Stackable)|a=5%|am=25%|t=180s}}.<ref name=\'ULTZZ_fullmetal_5\'>ULTZZ - Full Metal Jacket V, https://twitter.com/ULTZZ/status/1134804289451249665</ref><ref name="Kamigame"/>
|atk=150
|type=
|hit_all=
|bullet_casting=2
|emp=1
|release_date=
|material1=Full Metal Jacket IV,5
|material2=Iron Cluster,30
|material3=Steel Liquid,25
|material4=Sand Brick,30
}}',
      '20201' => '{{Bullet/Row
|id=20201
|name=Exploder
|jpname=エクスプローダー
|desc=Chance to gain {{status|ATK Up (Stackable)|t=Indefinite}}.<br/>Chance to inflict {{status|DEF Lowered (Stackable)|t=180s}} on foe.
|atk=50
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Full Metal Jacket,3
|material2=Explosive Material,4
|material3=Fine Sand Bottle,7
|material4=Blistering Ore,4
}}',
      '20202' => '{{Bullet/Row
|id=20202
|name=Exploder II
|jpname=エクスプローダーII
|desc=Chance to gain {{status|ATK Up (Stackable)|t=Indefinite}}.<br/>Chance to inflict {{status|DEF Lowered (Stackable)|t=180s}} on foe.
|atk=75
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Exploder,1
|material2=Explosive Material,8
|material3=Fine Sand Bottle,10
|material4=Blistering Ore,8
}}',
      '20203' => '{{Bullet/Row
|id=20203
|name=Exploder III
|jpname=エクスプローダーIII
|desc=Chance to gain {{status|ATK Up (Stackable)|a=7%|am=25%|t=Indefinite}}.<br/>Chance to inflict {{status|DEF Lowered (Stackable)|a=10%|am=15%|t=180s}} on foe.<ref name="Kamigame"/>
|atk=105
|type=
|hit_all=
|bullet_casting=1
|emp=2
|release_date=
|material1=Exploder II,2
|material2=Explosive Material,8
|material3=Fine Sand Bottle,15
|material4=Blistering Ore,15
}}',
      '20301' => '{{Bullet/Row
|id=20301
|name=Piercer
|jpname=アーマーピアシング
|desc=Chance to boost MC\'s critical hit rate and lower double attack rate (Stackable)
|atk=50
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Full Metal Jacket II,3
|material2=Iron Cluster,5
|material3=Coarse Alluvium,5
|material4=Flying Sprout,10
}}',
      '20302' => '{{Bullet/Row
|id=20302
|name=Piercer II
|jpname=アーマーピアシングII
|desc=Chance to boost MC\'s critical hit rate and lower double attack rate (Stackable)
|atk=70
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Piercer,1
|material2=Iron Cluster,8
|material3=Coarse Alluvium,8
|material4=Flying Sprout,14
}}',
      '20303' => '{{Bullet/Row
|id=20303
|name=Piercer III
|jpname=アーマーピアシングIII
|desc=Chance to boost MC\'s critical hit rate and lower double attack rate (Stackable)
|atk=70
|type=
|hit_all=
|bullet_casting=1
|emp=2
|release_date=
|material1=Piercer II,2
|material2=Iron Cluster,18
|material3=Coarse Alluvium,24
|material4=Flying Sprout,20
}}',
      '20401' => '{{Bullet/Row
|id=20401
|name=Silver Bullet
|jpname=シルバーバレット
|desc=Chance to gain {{Status|Chain Burst DMG Boosted (Stackable)|t=Indefinite}}.
|atk=30
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Full Metal Jacket II,3
|material2=Flawed Prism,8
|material3=Seismic Whorl,20
|material4=Lacrimosa,5
}}',
      '20402' => '{{Bullet/Row
|id=20402
|name=Silver Bullet II
|jpname=シルバーバレットII
|desc=Chance to gain {{Status|Chain Burst DMG Boosted (Stackable)|t=Indefinite}}.
|atk=50
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Silver Bullet,7
|material2=Flawed Prism,20
|material3=Seismic Whorl,30
|material4=Lacrimosa,10
}}',
      '20403' => '{{Bullet/Row
|id=20403
|name=Silver Bullet III
|jpname=シルバーバレットIII
|desc=Gain {{Status|Chain Burst DMG Boosted (Stackable)|t=Indefinite|a=10%|am=50%}}.<ref name=\'ULTZZ_silverbullet_3\'>ULTZZ - Silver Bullet III, https://twitter.com/ULTZZ/status/1133354019739455488</ref>
|atk=80
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Silver Bullet II,10
|material2=Flawed Prism,30
|material3=Seismic Whorl,40
|material4=Lacrimosa,20
}}',
      '20501' => '{{Bullet/Row
|id=20501
|name=Gold Bullet
|jpname=ゴールドバレット
|desc=~50% chance to gain {{Status|C.A. DMG Boosted (Stackable)|t=Indefinite|a=10%|am=50%}}.<ref name=\'kobito_opencv_goldbullet\'>Kobito opencv - Gold Bullet, https://twitter.com/kobito_opencv/status/1133694738668765184</ref>
|atk=80
|type=
|hit_all=
|bullet_casting=2
|emp=2
|release_date=
|material1=Silver Bullet,10
|material2=Full Metal Jacket V,2
|material3=Meteorite,1
|material4=
}}',
      '20502' => '{{Bullet/Row
|id=20502
|name=Gold Bullet II
|jpname=ゴールドバレットII
|desc=~70% chance to gain {{Status|C.A. DMG Boosted (Stackable)|t=Indefinite|a=10%|am=50%}}.<br/>Gain {{Status|C.A. DMG Cap Boosted (Stackable)|t=Indefinite|a=4%|am=20%}}.<ref name=\'kobito_opencv_goldbullet_2\'>Kobito opencv - Gold Bullet II, https://twitter.com/kobito_opencv/status/1135107730593669120</ref><ref name=\'ULTZZ_goldbullet_2\'>ULTZZ - Gold Bullet II, https://twitter.com/ULTZZ/status/1135075454107377664</ref><ref name="Kamigame"/>
|atk=100
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Gold Bullet,2
|material2=Gray Sandstone,5
|material3=Meteorite,5
|material4=Rusty Eave,5
}}',
      '20601' => '{{Bullet/Row
|id=20601
|name=Expert Model: Paradise Lost
|jpname=エンドモデル:パラダイス･ロスト
|desc=Surpasses DMG cap by 30%<ref name="K18Uu Bullets>@K18Uu, Bullet Cap Tests, https://twitter.com/K18Uu/status/1596951923256856577</ref>
|atk=200
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Full Metal Jacket V,3
|material2=Tears of the Apocalypse,150
|material3=Damascus Crystal,10
|material4=
}}',
      '20701' => '{{Bullet/Row
|id=20701
|name=Expert Model: Chaos Legion
|jpname=エンドモデル:ケイオスレギオン
|desc=Surpasses DMG cap by 30% / ~20% chance to inflict {{Status|Bore (Foe)|t=1T|a=50% DEF Down / Supplemental Damage: 100,000}} on foe<ref name="K18Uu Bullets />
|atk=200
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Full Metal Jacket V,3
|material2=Abyssal Wing,150
|material3=Damascus Crystal,10
|material4=
}}',
      '20801' => '{{Bullet/Row
|id=20801
|name=Expert Model: Anagenesis
|jpname=エンドモデル:アナゲンネーシス
|desc=Surpasses DMG cap by 30% / ~20% chance for all allies to gain a random {{tt|Fruit of Treachery|{{Status|Fruit of Treachery Alpha|t=2T}}<br />{{Status|Fruit of Treachery Beta|t=2T}}<br />{{Status|Fruit of Treachery Gamma|t=2T}}<br />{{Status|Fruit of Treachery Delta|t=2T}}}} buff<ref name="K18Uu Bullets /><ref name="k18 Belial Bullet>@K18Uu, Anagenesis Bullet Proc Chance, https://twitter.com/K18Uu/status/1596568890058113024</ref>
|atk=250
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Full Metal Jacket V,3
|material2=Cunning Devil\'s Horn,150
|material3=Damascus Crystal,10
|material4=
}}',
      '20901' => '{{Bullet/Row
|id=20901
|name=Expert Model: Genesis Nova
|jpname=エンドモデル:ジェネシス･ノヴァ
|desc=Surpasses DMG cap by 70% / 999,999 Plain DMG to all foes / Consume all bullets<ref name="K18Uu Bullets />
|atk=300
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Full Metal Jacket V,3
|material2=Ultimate Memory,150
|material3=Damascus Crystal,10
|material4=Gold Brick,1
}}',
      '21001' => '{{Bullet/Row
|id=21001
|name=Expert Model: Rationale Exitium
|jpname=エンドモデル:ラツィオ・エグゼティウム
|desc=Surpasses DMG cap by 50% / Ignore fire, water, earth, wind, light, and dark elemental resistances / 6-hit all-elemental DMG (Can only be loaded into 1 weapon once)<ref name="k18uu hexa faa bullets">@K18Uu, Hexachromatic & Lucilius Zero Bullets https://x.com/K18Uu/status/1961604817350009002</ref>
|atk=400
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Expert Model: Anagenesis,3
|material2=Provenance Crystal,200
|material3=Gold Brick,1
|material4=Eternity Sand,3
}}',
      '21101' => '{{Bullet/Row
|id=21101
|name=Expert Model: Anti Vasileia
|jpname=エンドモデル:アンチ・バシレイア
|desc=Supplement DMG dealt by 100% / Surpasses DMG cap by 70% (Can only be loaded into 1 weapon once / MC starts battle with {{status|Grand Finale Countdown (Bullet) 6}} / Progress Countdown by 1 when this bullet is fired / 2-hit, 6,666,666 Plain DMG to a foe at end of turn when Countdown reaches 0)<ref name="k18uu hexa faa bullets" />
|atk=400
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Expert Model: Paradise Lost,3
|material2=Apocalyptic Black Feather,200
|material3=Gold Brick,1
|material4=Eternity Sand,3
}}',
      '30101' => '{{Bullet/Row
|id=30101
|name=Shotshell
|jpname=シェルバレット
|desc=
|atk=35
|type=
|hit_all=Yes
|bullet_casting=
|emp=
|release_date=
|material1=Prosperity Flame,4
|material2=Explosive Material,5
|material3=Blistering Ore,5
|material4=
}}',
      '30102' => '{{Bullet/Row
|id=30102
|name=Shotshell II
|jpname=シェルバレットII
|desc=
|atk=50
|type=
|hit_all=Yes
|bullet_casting=1
|emp=1
|release_date=
|material1=Prosperity Flame,7
|material2=Explosive Material,5
|material3=Blistering Ore,7
|material4=Shotshell,1
}}',
      '30103' => '{{Bullet/Row
|id=30103
|name=Shotshell III
|jpname=シェルバレットIII
|desc=
|atk=70
|type=
|hit_all=Yes
|bullet_casting=1
|emp=2
|release_date=
|material1=Prosperity Flame,10
|material2=Explosive Material,10
|material3=Blistering Ore,10
|material4=Shotshell II,2
}}',
      '30104' => '{{Bullet/Row
|id=30104
|name=Shotshell IV
|jpname=シェルバレットIV
|desc=
|atk=105
|type=
|hit_all=Yes
|bullet_casting=1
|emp=3
|release_date=
|material1=Prosperity Flame,20
|material2=Explosive Material,30
|material3=Blistering Ore,20
|material4=Shotshell III,5
}}',
      '30105' => '{{Bullet/Row
|id=30105
|name=Shotshell V
|jpname=シェルバレットV
|desc=
|atk=120
|type=
|hit_all=Yes
|bullet_casting=2
|emp=1
|release_date=
|material1=Prosperity Flame,30
|material2=Explosive Material,40
|material3=Blistering Ore,30
|material4=Shotshell IV,5
}}',
      '30201' => '{{Bullet/Row
|id=30201
|name=Strike Shell
|jpname=アサルトシェル
|desc=Self-inflict {{Status|DEF Lowered (Stackable / Unremovable)|t=Indefinite}}.
|atk=90
|type=
|hit_all=Yes
|bullet_casting=
|emp=
|release_date=
|material1=Prosperity Flame,7
|material2=Explosive Material,15
|material3=Blistering Ore,5
|material4=
}}',
      '30202' => '{{Bullet/Row
|id=30202
|name=Strike Shell II
|jpname=アサルトシェルII
|desc=Self-inflict {{Status|DEF Lowered (Stackable / Unremovable)|t=Indefinite}}.
|atk=135
|type=
|hit_all=Yes
|bullet_casting=1
|emp=1
|release_date=
|material1=Prosperity Flame,10
|material2=Explosive Material,20
|material3=Blistering Ore,16
|material4=Strike Shell,1
}}',
      '30301' => '{{Bullet/Row
|id=30301
|name=Fire Cylinder
|jpname=ヒートシリンダー
|desc=Chance to inflict {{Status|Fire Lowered (Stackable)}} on all foes.
|atk=50
|type=
|hit_all=Yes
|bullet_casting=
|emp=
|release_date=
|material1=Antique Cloth,2
|material2=Explosive Material,5
|material3=Infernal Whorl,30
|material4=
}}',
      '30302' => '{{Bullet/Row
|id=30302
|name=Fire Cylinder II
|jpname=ヒートシリンダーII
|desc=Chance to inflict {{Status|Fire Lowered (Stackable)}} on all foes.
|atk=90
|type=
|hit_all=Yes
|bullet_casting=1
|emp=1
|release_date=
|material1=Antique Cloth,5
|material2=Explosive Material,10
|material3=Resolute Reactor,5
|material4=Fire Cylinder,1
}}',
      '30401' => '{{Bullet/Row
|id=30401
|name=Water Cylinder
|jpname=コールドシリンダー
|desc=Chance to inflict {{Status|Water Lowered (Stackable)}} on all foes.
|atk=50
|type=
|hit_all=Yes
|bullet_casting=
|emp=
|release_date=
|material1=Antique Cloth,2
|material2=Explosive Material,5
|material3=Tidal Whorl,30
|material4=
}}',
      '30402' => '{{Bullet/Row
|id=30402
|name=Water Cylinder II
|jpname=コールドシリンダーII
|desc=Chance to inflict {{Status|Water Lowered (Stackable)}} on all foes.
|atk=90
|type=
|hit_all=Yes
|bullet_casting=1
|emp=1
|release_date=
|material1=Antique Cloth,5
|material2=Explosive Material,10
|material3=Fanned Fin,5
|material4=Water Cylinder,1
}}',
      '30501' => '{{Bullet/Row
|id=30501
|name=Earth Cylinder
|jpname=アースシリンダー
|desc=Chance to inflict {{Status|Earth Lowered (Stackable)}} on all foes.
|atk=50
|type=
|hit_all=Yes
|bullet_casting=
|emp=
|release_date=
|material1=Antique Cloth,2
|material2=Explosive Material,5
|material3=Seismic Whorl,30
|material4=
}}',
      '30502' => '{{Bullet/Row
|id=30502
|name=Earth Cylinder II
|jpname=アースシリンダーII
|desc=Chance to inflict {{Status|Earth Lowered (Stackable)}} on all foes.
|atk=90
|type=
|hit_all=Yes
|bullet_casting=1
|emp=1
|release_date=
|material1=Antique Cloth,5
|material2=Explosive Material,10
|material3=Genesis Bud,5
|material4=Earth Cylinder,1
}}',
      '30601' => '{{Bullet/Row
|id=30601
|name=Wind Cylinder
|jpname=ゲイルシリンダー
|desc=Chance to inflict {{Status|Wind Lowered (Stackable)}} on all foes.
|atk=50
|type=
|hit_all=Yes
|bullet_casting=
|emp=
|release_date=
|material1=Antique Cloth,2
|material2=Explosive Material,5
|material3=Tempest Whorl,30
|material4=
}}',
      '30602' => '{{Bullet/Row
|id=30602
|name=Wind Cylinder II
|jpname=ゲイルシリンダーII
|desc=Chance to inflict {{Status|Wind Lowered (Stackable)}} on all foes.
|atk=90
|type=
|hit_all=Yes
|bullet_casting=1
|emp=1
|release_date=
|material1=Antique Cloth,5
|material2=Explosive Material,10
|material3=Green Dragon Eye,5
|material4=Wind Cylinder,1
}}',
      '30701' => '{{Bullet/Row
|id=30701
|name=Light Cylinder
|jpname=サンダーシリンダー
|desc=Chance to inflict {{Status|Light Lowered (Stackable)}} on all foes.
|atk=50
|type=
|hit_all=Yes
|bullet_casting=
|emp=
|release_date=
|material1=Antique Cloth,2
|material2=Explosive Material,5
|material3=Radiant Whorl,30
|material4=
}}',
      '30702' => '{{Bullet/Row
|id=30702
|name=Light Cylinder II
|jpname=サンダーシリンダーII
|desc=Chance to inflict {{Status|Light Lowered (Stackable)}} on all foes.
|atk=90
|type=
|hit_all=Yes
|bullet_casting=1
|emp=1
|release_date=
|material1=Antique Cloth,5
|material2=Explosive Material,10
|material3=Primal Bit,5
|material4=Light Cylinder,1
}}',
      '30801' => '{{Bullet/Row
|id=30801
|name=Dark Cylinder
|jpname=ダークシリンダー
|desc=Chance to inflict {{Status|Dark Lowered (Stackable)}} on all foes.
|atk=50
|type=
|hit_all=Yes
|bullet_casting=
|emp=
|release_date=
|material1=Antique Cloth,2
|material2=Explosive Material,5
|material3=Umbral Whorl,30
|material4=
}}',
      '30802' => '{{Bullet/Row
|id=30802
|name=Dark Cylinder II
|jpname=ダークシリンダーII
|desc=Chance to inflict {{Status|Dark Lowered (Stackable)}} on all foes.
|atk=90
|type=
|hit_all=Yes
|bullet_casting=1
|emp=1
|release_date=
|material1=Antique Cloth,5
|material2=Explosive Material,10
|material3=Black Fog Sphere,5
|material4=Dark Cylinder,1
}}',
      '30901' => '{{Bullet/Row
|id=30901
|name=Guard Breaker
|jpname=アーマーブレイカー
|desc=Chance to lower all foes\' DEF (Stackable)
|atk=50
|type=
|hit_all=Yes
|bullet_casting=
|emp=
|release_date=
|material1=Steel Liquid,10
|material2=Prosperity Flame,20
|material3=Piercer II,5
|material4=Piercer,5
}}',
      '30902' => '{{Bullet/Row
|id=30902
|name=Guard Breaker II
|jpname=アーマーブレイカーII
|desc=Chance to lower all foes\' DEF (Stackable)
|atk=75
|type=
|hit_all=Yes
|bullet_casting=1
|emp=1
|release_date=
|material1=Steel Liquid,24
|material2=Explosive Material,20
|material3=Guard Breaker,1
|material4=
}}',
      '31001' => '{{Bullet/Row
|id=31001
|name=Slug Shot
|jpname=スラッグショット
|desc=Hit to MC\'s double attack rate and DEF (Stackable)
|atk=200
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Steel Liquid,20
|material2=Prosperity Flame,20
|material3=Full Metal Jacket III,5
|material4=Iron Bullet III,5
}}',
      '31002' => '{{Bullet/Row
|id=31002
|name=Slug Shot II
|jpname=スラッグショットII
|desc=Hit to MC\'s double attack rate and DEF (Stackable)
|atk=300
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Steel Liquid,70
|material2=Explosive Material,20
|material3=Slug Shot,1
|material4=
}}',
      '31101' => '{{Bullet/Row
|id=31101
|name=Sticky Shell
|jpname=スティッキーシェル
|desc=Hit to all foes\' multiattack rate
|atk=50
|type=
|hit_all=Yes
|bullet_casting=
|emp=
|release_date=
|material1=Steel Liquid,10
|material2=Corroded Cartridge,8
|material3=Piercer II,5
|material4=Piercer,5
}}',
      '31102' => '{{Bullet/Row
|id=31102
|name=Sticky Shell II
|jpname=スティッキーシェルII
|desc=Inflict {{Status|DA Down|t=180S|a=50%}} and {{Status|TA Down|t=180S|a=50%}} on all foes.<ref name=\'ULTZZ_stickyshell_2\'>https://twitter.com/ULTZZ/status/1138103242812903424</ref>
|atk=80
|type=
|hit_all=Yes
|bullet_casting=2
|emp=2
|release_date=
|material1=Steel Liquid,20
|material2=Corroded Cartridge,15
|material3=Sticky Shell,10
|material4=
}}',
      '31201' => '{{Bullet/Row
|id=31201
|name=Chaser Shell
|jpname=チェイスシェル
|desc=~80% chance to gain {{Status|Bonus DMG|a=15%|t=2T}}
|atk=60
|type=
|hit_all=Yes
|bullet_casting=2
|emp=3
|release_date=
|material1=Broken Teacup,10
|material2=Raw Gemstone,10
|material3=Malice Fragment,5
|material4=Shotshell V,2
}}',
      '31301' => '{{Bullet/Row
|id=31301
|name=Enhancing Shell
|jpname=エンハンスシェル
|desc=~50% chance for each ally to gain {{status|DMG Boosted|t=2.5T|a=5% of foe\'s max HP (Damage cap: 50,000)}}.<ref name=\'kobito_opencv_enhancingshell\'>Kobito opencv - Enhancing Shell, https://twitter.com/kobito_opencv/status/1133694737414647809</ref><ref name=\'ULTZZ_enhancingshell\'>ULTZZ - Enhancing Shell, https://twitter.com/ULTZZ/status/1135175211555336192</ref>
|atk=90
|type=
|hit_all=Yes
|bullet_casting=2
|emp=3
|release_date=
|material1=Jumbo Beast Bone,10
|material2=Translucent Silk,10
|material3=Malice Fragment,5
|material4=Shotshell V,2
}}',
      '31401' => '{{Bullet/Row
|id=31401
|name=Catastrophe Cylinder
|jpname=カタストロフィシリンダー
|desc=Chance to gain {{status|C.A. DMG Boosted (1 time)|t=i}} and {{status|C.A. DMG Cap Boosted (1 time)|t=i}}.
|atk=140
|type=
|hit_all=Yes
|bullet_casting=2
|emp=3
|release_date=
|material1=Shotshell V,1
|material2=Primeval Horn,300
|material3=
|material4=
}}',
      '31501' => '{{Bullet/Row
|id=31501
|name=Akashic Cylinder
|jpname=アカシックシリンダー
|desc=Chance to progress battle turn by 1
|atk=140
|type=
|hit_all=Yes
|bullet_casting=2
|emp=3
|release_date=
|material1=Shotshell V,1
|material2=Hollow Key,300
|material3=
|material4=
}}',
      '31601' => '{{Bullet/Row
|id=31601
|name=Cosmos Cylinder
|jpname=コスモスシリンダー
|desc=Chance to gain {{Status|Peacemaker\'s Wings|t=3T|a=20% ATK Up, 20% DEF Up, 5% of damage dealt (Healing cap: 1000)|m=n|c=Verification needed}}.
|atk=140
|type=
|hit_all=Yes
|bullet_casting=2
|emp=3
|release_date=
|material1=Shotshell V,1
|material2=Verdant Azurite,300
|material3=
|material4=
}}',
      '31701' => '{{Bullet/Row
|id=31701
|name=Expert Model: Apocalypse
|jpname=エンドモデル:アポカリプス
|desc=Deals DMG to all foes / Surpasses DMG cap by 50% / 1 {{tt|random buff|{{status|Flurry (2-hit)|t=2T}}<br />{{status|Supplemental DMG|a=50,000|t=2T}}<br />{{status|DMG Cap Boosted|a=10%|t=2T}}<br />{{status|Critical Hit Rate Boosted|a=20%|p=100%|t=2T}}<br />{{status|TA Up|a=100%|t=2T}}<br />{{status|ATK Up|a=30%|t=2T}} }} and 1 {{tt|random debuff|{{status|Supplemental DMG (Taken)|a=1000|t=2T}}<br />{{status|Slashed|a=1000|t=2T}}<br />{{status|DEF Lowered|a=20%|t=2T}}<br />{{status|Halation|t=2T}}<br />{{status|Debuff Resistance Lowered|t=2T}}<br />{{status|Strong Armed|t=2T}} }} to MC.<ref name="k18uu hexa faa bullets" />
|atk=200
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Catastrophe Cylinder,1
|material2=Akashic Cylinder,1
|material3=Cosmos Cylinder,1
|material4=Apocalyptic Black Feather,100
}}',
      '40101' => '{{Bullet/Row
|id=40101
|name=Ifrit Point
|jpname=イフリートポイント
|desc=Chance to gain {{status|Fire ATK Boosted (Stackable)|t=Indefinite}}.
|atk=80
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Fire Orb,20
|material2=Inferno Orb,10
|material3=Infernal Whorl,20
|material4=Ifrit Anima,20
}}',
      '40102' => '{{Bullet/Row
|id=40102
|name=Ifrit Point II
|jpname=イフリートポイントII
|desc=Chance to gain {{status|Fire ATK Boosted (Stackable)|t=Indefinite}}.
|atk=100
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Red Tome,24
|material2=Hellfire Scroll,12
|material3=Red Dragon Scale,16
|material4=Ifrit Point,2
}}',
      '40103' => '{{Bullet/Row
|id=40103
|name=Ifrit Point III
|jpname=イフリートポイントIII
|desc=Gain {{status|Fire ATK Boosted (Stackable)|t=Indefinite|a=10%|am=30%}}.<ref name=\'kobito_opencv_ifrit_3\'>Kobito opencv - Ifrit Point III, https://twitter.com/kobito_opencv/status/1133694736064057345</ref>
|atk=120
|type=
|hit_all=
|bullet_casting=2
|emp=2
|release_date=
|material1=True Fire Anima,20
|material2=Fire Quartz,10
|material3=Red Dragon Scale,20
|material4=Ifrit Point II,5
}}',
      '40201' => '{{Bullet/Row
|id=40201
|name=Cocytus Point
|jpname=コキュートスポイント
|desc=Chance to gain {{status|Water ATK Boosted (Stackable)|t=Indefinite}}.
|atk=80
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Water Orb,20
|material2=Frost Orb,10
|material3=Tidal Whorl,20
|material4=Cocytus Anima,20
}}',
      '40202' => '{{Bullet/Row
|id=40202
|name=Cocytus Point II
|jpname=コキュートスポイントII
|desc=Chance to gain {{status|Water ATK Boosted (Stackable)|t=Indefinite}}.
|atk=100
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Blue Tome,24
|material2=Flood Scroll,12
|material3=Blue Dragon Scale,16
|material4=Cocytus Point,2
}}',
      '40203' => '{{Bullet/Row
|id=40203
|name=Cocytus Point III
|jpname=コキュートスポイントIII
|desc=Gain {{status|Water ATK Boosted (Stackable)|t=Indefinite|a=10%|am=30%}}.<!--assumed to be the same as ifrit point III-->
|atk=120
|type=
|hit_all=
|bullet_casting=2
|emp=2
|release_date=
|material1=True Water Anima,20
|material2=Water Quartz,10
|material3=Blue Dragon Scale,20
|material4=Cocytus Point II,5
}}',
      '40301' => '{{Bullet/Row
|id=40301
|name=Vohu Manah Point
|jpname=ウォフマナフポイント
|desc=Chance to gain {{status|Earth ATK Boosted (Stackable)|t=Indefinite}}.
|atk=80
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Earth Orb,20
|material2=Rumbling Orb,10
|material3=Seismic Whorl,20
|material4=Vohu Manah Anima,20
}}',
      '40302' => '{{Bullet/Row
|id=40302
|name=Vohu Manah Point II
|jpname=ウォフマナフポイントII
|desc=Chance to gain {{status|Earth ATK Boosted (Stackable)|t=Indefinite}}.
|atk=100
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Brown Tome,24
|material2=Thunder Scroll,12
|material3=Brown Dragon Scale,16
|material4=Vohu Manah Point,2
}}',
      '40303' => '{{Bullet/Row
|id=40303
|name=Vohu Manah Point III
|jpname=ウォフマナフポイントIII
|desc=Gain {{status|Earth ATK Boosted (Stackable)|t=Indefinite|a=10%|am=30%}}.<ref name=\'ULTZZ_vohu_3\'>ULTZZ - Vohu Manah Point III, https://twitter.com/ULTZZ/status/1133374908036145153</ref>
|atk=120
|type=
|hit_all=
|bullet_casting=2
|emp=2
|release_date=
|material1=True Earth Anima,20
|material2=Earth Quartz,10
|material3=Brown Dragon Scale,20
|material4=Vohu Manah Point II,5
}}',
      '40401' => '{{Bullet/Row
|id=40401
|name=Sagittarius Point
|jpname=サジタリウスポイント
|desc=Chance to gain {{status|Wind ATK Boosted (Stackable)|t=Indefinite}}.
|atk=80
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Wind Orb,20
|material2=Cyclone Orb,10
|material3=Tempest Whorl,20
|material4=Sagittarius Anima,20
}}',
      '40402' => '{{Bullet/Row
|id=40402
|name=Sagittarius Point II
|jpname=サジタリウスポイントII
|desc=Chance to gain {{status|Wind ATK Boosted (Stackable)|t=Indefinite}}.
|atk=100
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Green Tome,24
|material2=Gale Scroll,12
|material3=Green Dragon Scale,16
|material4=Sagittarius Point,2
}}',
      '40403' => '{{Bullet/Row
|id=40403
|name=Sagittarius Point III
|jpname=サジタリウスポイントIII
|desc=Gain {{status|Wind ATK Boosted (Stackable)|t=Indefinite|a=10%|am=30%}}.<!--assumed to be the same as ifrit point III-->
|atk=120
|type=
|hit_all=
|bullet_casting=2
|emp=2
|release_date=
|material1=True Wind Anima,20
|material2=Wind Quartz,10
|material3=Green Dragon Scale,20
|material4=Sagittarius Point II,5
}}',
      '40501' => '{{Bullet/Row
|id=40501
|name=Corow Point
|jpname=コロゥポイント
|desc=Chance to gain {{status|Light ATK Boosted (Stackable)|t=Indefinite}}.
|atk=80
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Light Orb,20
|material2=Shining Orb,10
|material3=Radiant Whorl,20
|material4=Corow Anima,20
}}',
      '40502' => '{{Bullet/Row
|id=40502
|name=Corow Point II
|jpname=コロゥポイントII
|desc=Chance to gain {{status|Light ATK Boosted (Stackable)|t=Indefinite}}.
|atk=100
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=White Tome,24
|material2=Skylight Scroll,12
|material3=White Dragon Scale,16
|material4=Corow Point,2
}}',
      '40503' => '{{Bullet/Row
|id=40503
|name=Corow Point III
|jpname=コロゥポイントIII
|desc=Gain {{status|Light ATK Boosted (Stackable)|t=Indefinite|a=10%|am=30%}}.<!--assumed to be the same as ifrit point III-->
|atk=120
|type=
|hit_all=
|bullet_casting=2
|emp=2
|release_date=
|material1=True Light Anima,20
|material2=Light Quartz,10
|material3=White Dragon Scale,20
|material4=Corow Point II,5
}}',
      '40601' => '{{Bullet/Row
|id=40601
|name=Diablo Point
|jpname=ディアボロスポイント
|desc=Chance to gain {{status|Dark ATK Boosted (Stackable)|t=Indefinite}}.
|atk=80
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Dark Orb,20
|material2=Abysm Orb,10
|material3=Umbral Whorl,20
|material4=Diablo Anima,20
}}',
      '40602' => '{{Bullet/Row
|id=40602
|name=Diablo Point II
|jpname=ディアボロスポイントII
|desc=Chance to gain {{status|Dark ATK Boosted (Stackable)|t=Indefinite}}.
|atk=100
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Black Tome,24
|material2=Chasm Scroll,12
|material3=Black Dragon Scale,16
|material4=Diablo Point,2
}}',
      '40603' => '{{Bullet/Row
|id=40603
|name=Diablo Point III
|jpname=ディアボロスポイントIII
|desc=Gain {{status|Dark ATK Boosted (Stackable)|t=Indefinite|a=10%|am=30%}}.<!--assumed to be the same as ifrit point III-->
|atk=120
|type=
|hit_all=
|bullet_casting=2
|emp=2
|release_date=
|material1=True Dark Anima,20
|material2=Dark Quartz,10
|material3=Black Dragon Scale,20
|material4=Diablo Point II,5
}}',
      '40701' => '{{Bullet/Row
|id=40701
|name=Agni Point
|jpname=アグニスポイント
|desc=Chance for each ally to gain {{status|Fire ATK Boosted (Stackable)|t=Indefinite}}.
|atk=65
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Ifrit Point II,3
|material2=Fire Grimoire,5
|material3=Blood Amber,7
|material4=
}}',
      '40702' => '{{Bullet/Row
|id=40702
|name=Agni Point II
|jpname=アグニスポイントII
|desc=Chance for each ally to gain {{status|Fire ATK Boosted (Stackable)|t=Indefinite}}.
|atk=100
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Agni Point,1
|material2=Fire Grimoire,7
|material3=Fire Quartz,30
|material4=Light Quartz,20
}}',
      '40703' => '{{Bullet/Row
|id=40703
|name=Agni Point III
|jpname=アグニスポイントIII
|desc=All allies gain {{status|Fire ATK Boosted (Stackable)|t=Indefinite|a=5%|am=25%}}.<ref name=\'kobito_opencv_agni_3\'>Kobito opencv - Agni Point III, https://twitter.com/kobito_opencv/status/1133694734507974657</ref>
|atk=120
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Rubeus Centrum,20
|material2=Fire Quartz,20
|material3=Fire Urn,3
|material4=Agni Point II,5
}}',
      '40704' => '{{Bullet/Row
|id=40704
|name=Agni Point IV
|jpname=アグニスポイントIV
|desc=Deals 10% amplified DMG when at elemental advantage.<ref name="GameWith Bullets>GameWith, Bullets, https://グランブルーファンタジー.gamewith.jp/article/show/216867</ref>
|atk=120
|type=
|hit_all=
|bullet_casting=
|emp=?
|release_date=
|material1=Agni Point III,1
|material2=Wilnas\'s Jewel,100
|material3=Smoldering Rubble,50
|material4=True Dragon\'s Golden Scale,30
}}',
      '40801' => '{{Bullet/Row
|id=40801
|name=Neptune Point
|jpname=ネプチューンポイント
|desc=Chance for each ally to gain {{status|Water ATK Boosted (Stackable)|t=Indefinite}}.
|atk=65
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Cocytus Point II,3
|material2=Water Grimoire,5
|material3=Blood Amber,7
|material4=
}}',
      '40802' => '{{Bullet/Row
|id=40802
|name=Neptune Point II
|jpname=ネプチューンポイントII
|desc=Chance for each ally to gain {{status|Water ATK Boosted (Stackable)|t=Indefinite}}.
|atk=100
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Neptune Point,1
|material2=Water Grimoire,7
|material3=Water Quartz,30
|material4=Dark Quartz,20
}}',
      '40803' => '{{Bullet/Row
|id=40803
|name=Neptune Point III
|jpname=ネプチューンポイントIII
|desc=All allies gain {{status|Water ATK Boosted (Stackable)|t=Indefinite|a=5%|am=25%}}.<!--assumed to be the same as agni point III-->
|atk=120
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Indicus Centrum,20
|material2=Water Quartz,20
|material3=Water Urn,3
|material4=Neptune Point II,5
}}',
      '40804' => '{{Bullet/Row
|id=40804
|name=Neptune Point IV
|jpname=ネプチューンポイントIV
|desc=Deals 10% amplified DMG when at elemental advantage.<ref name="GameWith Bullets />
|atk=120
|type=
|hit_all=
|bullet_casting=
|emp=?
|release_date=
|material1=Neptune Point III,1
|material2=Wamdus\'s Jewel,100
|material3=Abyssal Tragedy,50
|material4=True Dragon\'s Golden Scale,30
}}',
      '40901' => '{{Bullet/Row
|id=40901
|name=Titan Point
|jpname=ティターンポイント
|desc=Chance for each ally to gain {{status|Earth ATK Boosted (Stackable)|t=Indefinite}}.
|atk=65
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Vohu Manah Point II,3
|material2=Earth Grimoire,5
|material3=Blood Amber,7
|material4=
}}',
      '40902' => '{{Bullet/Row
|id=40902
|name=Titan Point II
|jpname=ティターンポイントII
|desc=Chance for each ally to gain {{status|Earth ATK Boosted (Stackable)|t=Indefinite}}.
|atk=100
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Titan Point,1
|material2=Earth Grimoire,7
|material3=Earth Quartz,30
|material4=Dark Quartz,20
}}',
      '40903' => '{{Bullet/Row
|id=40903
|name=Titan Point III
|jpname=ティターンポイントIII
|desc=All allies gain {{status|Earth ATK Boosted (Stackable)|t=Indefinite|a=5%|am=25%}}.<!--assumed to be the same as agni point III-->
|atk=120
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Luteus Centrum,20
|material2=Earth Quartz,20
|material3=Earth Urn,3
|material4=Titan Point II,5
}}',
      '40904' => '{{Bullet/Row
|id=40904
|name=Titan Point IV
|jpname=ティターンポイントIV
|desc=Deals 10% amplified DMG when at elemental advantage.<ref name="GameWith Bullets />
|atk=120
|type=
|hit_all=
|bullet_casting=
|emp=?
|release_date=
|material1=Titan Point III,1
|material2=Galleon\'s Jewel,100
|material3=Insular Core,50
|material4=True Dragon\'s Golden Scale,30
}}',
      '41001' => '{{Bullet/Row
|id=41001
|name=Zephyrus Point
|jpname=ゼピュロスポイント
|desc=Chance for each ally to gain {{status|Wind ATK Boosted (Stackable)|t=Indefinite}}.
|atk=65
|type=
|hit_all=
|bullet_casting=
|emp=
|release_date=
|material1=Sagittarius Point II,3
|material2=Wind Grimoire,5
|material3=Blood Amber,7
|material4=
}}',
      '41002' => '{{Bullet/Row
|id=41002
|name=Zephyrus Point II
|jpname=ゼピュロスポイントII
|desc=Chance for each ally to gain {{status|Wind ATK Boosted (Stackable)|t=Indefinite}}.
|atk=100
|type=
|hit_all=
|bullet_casting=1
|emp=1
|release_date=
|material1=Zephyrus Point,1
|material2=Wind Grimoire,7
|material3=Wind Quartz,30
|material4=Light Quartz,20
}}',
      '41003' => '{{Bullet/Row
|id=41003
|name=Zephyrus Point III
|jpname=ゼピュロスポイントIII
|desc=All allies gain {{status|Wind ATK Boosted (Stackable)|t=Indefinite|a=5%|am=25%}}.<!--assumed to be the same as agni point III-->
|atk=120
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Galbinus Centrum,20
|material2=Wind Quartz,20
|material3=Wind Urn,3
|material4=Zephyrus Point II,5
}}',
      '41004' => '{{Bullet/Row
|id=41004
|name=Zephyrus Point IV
|jpname=ゼピュロスポイントIV
|desc=Deals 10% amplified DMG when at elemental advantage.<ref name="GameWith Bullets />
|atk=120
|type=
|hit_all=
|bullet_casting=
|emp=?
|release_date=
|material1=Zephyrus Point III,1
|material2=Ewiyar\'s Jewel,100
|material3=Gale Rock,50
|material4=True Dragon\'s Golden Scale,30
}}',
      '41101' => '{{Bullet/Row
|id=41101
|name=Zeus Point
|jpname=ゼウスポイント
|desc=Chance for all allies to gain {{status|Light ATK Boosted (Stackable)|t=Indefinite}}.
|atk=65
|type=
|hit_all=
|bullet_casting=2
|emp=1
|release_date=
|material1=Corow Point II,3
|material2=Fire Grimoire,5
|material3=Wind Grimoire,5
|material4=Blood Amber,7
}}',
      '41102' => '{{Bullet/Row
|id=41102
|name=Zeus Point II
|jpname=ゼウスポイントII
|desc=Chance for all allies to gain {{status|Light ATK Boosted (Stackable)|t=Indefinite}}.
|atk=100
|type=
|hit_all=
|bullet_casting=2
|emp=2
|release_date=
|material1=Zeus Point,1
|material2=Fire Grimoire,7
|material3=Wind Grimoire,7
|material4=Light Quartz,20
}}',
      '41103' => '{{Bullet/Row
|id=41103
|name=Zeus Point III
|jpname=ゼウスポイントIII
|desc=All allies gain {{status|Light ATK Boosted (Stackable)|t=Indefinite|a=5%|am=25%}}.<!--assumed to be the same as agni point III-->
|atk=120
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Niveus Centrum,20
|material2=Light Quartz,20
|material3=Light Urn,3
|material4=Zeus Point II,5
}}',
      '41104' => '{{Bullet/Row
|id=41104
|name=Zeus Point IV
|jpname=ゼウスポイントIV
|desc=Deals 10% amplified DMG when at elemental advantage.<ref name="GameWith Bullets />
|atk=120
|type=
|hit_all=
|bullet_casting=
|emp=?
|release_date=
|material1=Zeus Point III,1
|material2=Lu Woh\'s Jewel,100
|material3=Thunderbolt Wheel,50
|material4=True Dragon\'s Golden Scale,30
}}',
      '41201' => '{{Bullet/Row
|id=41201
|name=Hades Point
|jpname=ハデスポイント
|desc=Chance for all allies to gain {{status|Dark ATK Boosted (Stackable)|t=Indefinite}}.
|atk=65
|type=
|hit_all=
|bullet_casting=2
|emp=1
|release_date=
|material1=Diablo Point II,3
|material2=Water Grimoire,5
|material3=Earth Grimoire,5
|material4=Blood Amber,7
}}',
      '41202' => '{{Bullet/Row
|id=41202
|name=Hades Point II
|jpname=ハデスポイントIV
|desc=Chance for all allies to gain {{status|Dark ATK Boosted (Stackable)|t=Indefinite}}.
|atk=100
|type=
|hit_all=
|bullet_casting=2
|emp=2
|release_date=
|material1=Hades Point,1
|material2=Water Grimoire,7
|material3=Earth Grimoire,7
|material4=Dark Quartz,20
}}',
      '41203' => '{{Bullet/Row
|id=41203
|name=Hades Point III
|jpname=ハデスポイントIII
|desc=All allies gain {{status|Dark ATK Boosted (Stackable)|t=Indefinite|a=5%|am=25%}}.<ref name=\'ULTZZ_hades_3\'>ULTZZ - Hades Point III, https://twitter.com/ULTZZ/status/1133371524033929216</ref>
|atk=120
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Ater Centrum,20
|material2=Dark Quartz,20
|material3=Dark Urn,3
|material4=Hades Point II,5
}}',
      '41204' => '{{Bullet/Row
|id=41204
|name=Hades Point IV
|jpname=ハデスポイントIV
|desc=Deals 10% amplified DMG when at elemental advantage.<ref name="GameWith Bullets />
|atk=120
|type=
|hit_all=
|bullet_casting=
|emp=?
|release_date=
|material1=Hades Point III,1
|material2=Fediel\'s Jewel,100
|material3=Todestrieb,50
|material4=True Dragon\'s Golden Scale,30
}}',
      '41301' => '{{Bullet/Row
|id=41301
|name=Expert Model: Hexachromatic
|jpname=エンドモデル:ヘキサクロマティック
|desc=Surpasses DMG cap by 30% / 20% chance of 1 random {{tt|Pearl|{{status|Vermillion Pearl (Bullet)|t=2T}}<br/>{{status|Azure Pearl (Bullet)|t=2T}}<br/>{{status|Gold Pearl (Bullet)|t=2T}}<br/>{{status|Emerald Pearl (Bullet)|t=2T}}<br/>{{status|White Pearl (Bullet)|t=2T}}<br/>{{status|Black Pearl (Bullet)|t=2T}}}} to MC (\'\'\'While in effect:\'\'\' 30% boost to ATK / 20% Bonus elemental DMG upon normal attacks based on Pearl)<ref name="k18uu hexa faa bullets" />
|atk=150
|type=
|hit_all=
|bullet_casting=2
|emp=3
|release_date=
|material1=Provenance Crystal,100
|material2=True Dragon\'s Golden Scale,200
|material3=Damascus Crystal,10
|material4=Eternity Sand,1
}}',
    }

    bullets.each do |attrs|
      Bullet.find_or_create_by!(granblue_id: attrs[:granblue_id]) do |b|
        b.assign_attributes(attrs)
        b.wiki_raw = wiki_data[attrs[:granblue_id]]
      end
    end
  end

  def down
    Bullet.where(granblue_id: %w[
      10101 10102 10103 10104 10105 10201 10202 10203 10204 10301
      10401 10501 10601 10701 10801 10901 11001 11101 11201 11301
      20101 20102 20103 20104 20105 20201 20202 20203 20301 20302
      20303 20401 20402 20403 20501 20502 20601 20701 20801 20901
      21001 21101 30101 30102 30103 30104 30105 30201 30202 30301
      30302 30401 30402 30501 30502 30601 30602 30701 30702 30801
      30802 30901 30902 31001 31002 31101 31102 31201 31301 31401
      31501 31601 31701 40101 40102 40103 40201 40202 40203 40301
      40302 40303 40401 40402 40403 40501 40502 40503 40601 40602
      40603 40701 40702 40703 40704 40801 40802 40803 40804 40901
      40902 40903 40904 41001 41002 41003 41004 41101 41102 41103
      41104 41201 41202 41203 41204 41301
    ]).destroy_all
  end
end
