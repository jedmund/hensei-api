class SeedPartyDifficulty < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    seed_components
    seed_tiers
    seed_rules
    DifficultyConfig.first || DifficultyConfig.create!(ruleset_version: 1)
  end

  def down
    DifficultyRule.delete_all
    Difficulty.delete_all
    DifficultyComponent.delete_all
    DifficultyConfig.delete_all
  end

  private

  def seed_components
    components = [
      { name: 'weapon',    weight: 3.0, enabled: true,  min_count_to_score: 5 },
      { name: 'character', weight: 1.5, enabled: true,  min_count_to_score: 3 },
      { name: 'summon',    weight: 3.5, enabled: true,  min_count_to_score: 2 },
      { name: 'job',       weight: 1.0, enabled: true,  min_count_to_score: 0 },
      { name: 'accessory', weight: 0.5, enabled: true,  min_count_to_score: 0 }
    ]
    components.each do |attrs|
      DifficultyComponent.find_or_create_by!(name: attrs[:name]) do |c|
        c.assign_attributes(attrs)
      end
    end
  end

  def seed_tiers
    tiers = [
      { slug: 'casual',  name: 'Casual',   color: '#86C5A8', min_score: 0,    max_score: 24.99,  sort_order: 0,
        description: 'Beginner-friendly setups built primarily from accessible characters, weapons, and summons.' },
      { slug: 'mid',     name: 'Mid',      color: '#7AB8E8', min_score: 25,   max_score: 49.99,  sort_order: 1,
        description: 'Solid mid-game teams with some investment but no rare endgame items.' },
      { slug: 'endgame', name: 'Endgame',  color: '#E2B16C', min_score: 50,   max_score: 79.99,  sort_order: 2,
        description: 'Endgame teams featuring rare or recently released items, deep uncaps, or notable awakenings.' },
      { slug: 'whale',   name: 'Whale',    color: '#D78EA0', min_score: 80,   max_score: 100.0,  sort_order: 3,
        description: 'High-investment teams featuring multiple Grand/Providence units, Trans5 weapons, and perpetuity-ringed characters.' }
    ]
    tiers.each do |attrs|
      Difficulty.find_or_create_by!(slug: attrs[:slug]) do |t|
        t.assign_attributes(attrs)
      end
    end
  end

  def seed_rules
    rules = [
      # Weapons -------------------------------------------------------------
      # Series rules use scale_by_count so each additional matching weapon
      # adds to the score, with a cap so the contribution doesn't run away.
      { name: 'Grand series weapons',                  component: 'weapon',
        rule_type: 'weapon_series_match', weight: 2.0,
        params: { 'slugs' => ['grand'], 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 5 } },
      { name: 'Providence/Draconic weapons',           component: 'weapon',
        rule_type: 'weapon_series_match', weight: 2.5,
        params: { 'slugs' => ['providence'], 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 3 } },
      { name: 'High awakening (level >= 5)',           component: 'weapon',
        rule_type: 'weapon_awakening_at_least', weight: 1.0,
        params: { 'min_level' => 5, 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 5 } },
      { name: 'Max awakening (level 10)',              component: 'weapon',
        rule_type: 'weapon_awakening_at_least', weight: 1.5,
        params: { 'min_level' => 10, 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 3 } },
      { name: 'Transcended weapons',                   component: 'weapon',
        rule_type: 'weapon_transcendence_at_least', weight: 1.5,
        params: { 'min_step' => 1, 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 5 } },
      { name: 'Trans5 weapon present',                 component: 'weapon',
        rule_type: 'weapon_transcendence_at_least', weight: 4.0,
        params: { 'min_step' => 5, 'min_count' => 1 } },
      { name: 'AX skills filled on 3+',                component: 'weapon',
        rule_type: 'weapon_ax_filled', weight: 1.5,
        params: { 'min_filled' => 1, 'min_count' => 3 } },
      { name: 'Both AX slots filled on 3+',            component: 'weapon',
        rule_type: 'weapon_ax_filled', weight: 2.0,
        params: { 'min_filled' => 2, 'min_count' => 3 } },
      { name: 'Befoulment present',                    component: 'weapon',
        rule_type: 'weapon_befoulment_filled', weight: 2.0,
        params: { 'min_count' => 1 } },
      { name: 'Recently released weapon (180d)',       component: 'weapon',
        rule_type: 'weapon_release_within_days', weight: 2.5,
        params: { 'days' => 180, 'min_count' => 1 } },
      { name: 'Flash/Legend exclusive weapons',        component: 'weapon',
        rule_type: 'weapon_promotion_includes', weight: 1.5,
        params: { 'promotions' => %w[Flash Legend], 'min_count' => 2 } },
      # Gacha weapons at high uncap weigh more than free ones at the same
      # uncap, since they cost more to obtain.
      { name: 'High uncap on gacha weapons',           component: 'weapon',
        rule_type: 'weapon_uncap_at_least', weight: 1.5,
        params: { 'min_uncap_level' => 5, 'min_count' => 1,
                  'gacha_filter' => 'gacha',
                  'scale_by_count' => true, 'max_count' => 5 } },
      { name: 'High uncap on free weapons',            component: 'weapon',
        rule_type: 'weapon_uncap_at_least', weight: 0.5,
        params: { 'min_uncap_level' => 5, 'min_count' => 3,
                  'gacha_filter' => 'free',
                  'scale_by_count' => true, 'max_count' => 5 } },

      # Characters ----------------------------------------------------------
      { name: 'Grand characters',                      component: 'character',
        rule_type: 'character_series_match', weight: 2.0,
        params: { 'slugs' => ['grand'], 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 3 } },
      { name: 'Eternal/Evoker characters',             component: 'character',
        rule_type: 'character_series_match', weight: 2.0,
        params: { 'slugs' => %w[eternal evoker], 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 3 } },
      { name: 'Seasonal characters',                   component: 'character',
        rule_type: 'character_seasonal', weight: 0.75,
        params: { 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 4 } },
      { name: 'Perpetuity ring on any character',      component: 'character',
        rule_type: 'character_perpetuity_ringed', weight: 3.5,
        params: { 'min_count' => 1 } },
      { name: 'Strong earring (>=15)',                 component: 'character',
        rule_type: 'character_earring_at_least', weight: 1.5,
        params: { 'min_strength' => 15, 'min_count' => 1 } },
      { name: 'Trans5 character present',              component: 'character',
        rule_type: 'character_transcendence_at_least', weight: 3.0,
        params: { 'min_step' => 5, 'min_count' => 1 } },
      { name: 'Recently released character (180d)',    component: 'character',
        rule_type: 'character_release_within_days', weight: 2.0,
        params: { 'days' => 180, 'min_count' => 1 } },

      # Summons -------------------------------------------------------------
      # Friend summons are excluded — they belong to the player joining the
      # raid, not the party owner.
      { name: 'Providence summons',                    component: 'summon',
        rule_type: 'summon_series_match', weight: 3.0,
        params: { 'slugs' => ['providence'], 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 3 } },
      { name: 'High uncap on gacha summons',           component: 'summon',
        rule_type: 'summon_uncap_at_least', weight: 1.5,
        params: { 'min_uncap_level' => 5, 'min_count' => 1,
                  'gacha_filter' => 'gacha',
                  'scale_by_count' => true, 'max_count' => 5 } },
      { name: 'High uncap on free summons',            component: 'summon',
        rule_type: 'summon_uncap_at_least', weight: 0.5,
        params: { 'min_uncap_level' => 5, 'min_count' => 3,
                  'gacha_filter' => 'free',
                  'scale_by_count' => true, 'max_count' => 5 } },
      { name: 'Trans5 summon present',                 component: 'summon',
        rule_type: 'summon_transcendence_at_least', weight: 4.0,
        params: { 'min_step' => 5, 'min_count' => 1 } },

      # Job -----------------------------------------------------------------
      { name: 'Row V job',                             component: 'job',
        rule_type: 'job_row', weight: 2.0,
        params: { 'rows' => ['5'] } },
      { name: 'Origin job',                            component: 'job',
        rule_type: 'job_row', weight: 3.0,
        params: { 'rows' => ['o1'] } },
      { name: 'Row IV with Ultimate Mastery',          component: 'job',
        rule_type: 'job_row', weight: 1.5,
        params: { 'rows' => ['4'], 'requires_ultimate_mastery' => true } },

      # Accessory -----------------------------------------------------------
      { name: 'Accessory equipped',                    component: 'accessory',
        rule_type: 'accessory_match', weight: 1.0,
        params: { 'accessory_types' => [1, 2] } }
    ]

    rules.each do |attrs|
      DifficultyRule.find_or_create_by!(name: attrs[:name]) do |r|
        r.assign_attributes(attrs.merge(active: true))
      end
    end
  end
end
