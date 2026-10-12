# frozen_string_literal: true

# Banner payloads in the shape of the game's responses, as the fetcher sends
# them: the `/gacha/list` lineup entry and the `/gacha/provision_ratio` tabs
module GachaBannerPayloads
  # [reward_id, game rarity (4 SSR, 3 SR, 2 R), game category, displayed %, rate-up]
  ORDINARY = [
    ['1040000001', 4, 0, '0.300', true], ['1040000002', 4, 0, '1.350', false], ['2040000001', 4, 2, '1.350', false],
    ['1030000001', 3, 0, '5.000', false], ['1030000002', 3, 1, '5.000', false], ['2030000001', 3, 2, '5.000', false],
    ['1020000001', 2, 0, '20.500', false], ['1020000002', 2, 1, '41.000', false], ['2020000001', 2, 2, '20.500', false]
  ].freeze

  def gacha_banner_payload(id: '211960', start: '2026/10/9 19:00', finish: '2026/10/12 18:59', guaranteed: true)
    tabs = { '1' => gacha_rate_tab(ORDINARY, [%w[SSレア 3.00%], %w[Sレア 15.00%], %w[レア 82.00%]]) }
    if guaranteed
      rows = ORDINARY.reject { |row| row[1] == 2 }
                     .map { |row| row[1] == 3 ? row.dup.tap { |r| r[3] = '32.333' } : row }
      tabs['2'] = gacha_rate_tab(rows, [%w[SSレア 3.00%], %w[Sレア 97.00%]])
    end
    { 'banner' => { 'id' => id, 'name' => 'レジェンド10連ガチャ', 'times' => '10',
                    'service_start' => start, 'service_end' => finish },
      'tabs' => tabs }
  end

  def gacha_rate_tab(rows, ratio)
    groups = rows.group_by { |row| row[1, 2] }.map do |(rarity, category), items|
      { 'rarity' => rarity, 'category' => category,
        'item' => items.map do |id, _, _, rate, up|
          { 'name' => "Item #{id}", 'drop_rate' => rate, 'reward_id' => id.to_i, 'incidence' => up ? '1' : nil,
            'is_season' => false }
        end }
    end
    { 'ratio' => ratio.map { |rare, value| { 'rare' => rare, 'ratio' => value } }, 'appear' => groups, 'tab_type' => 1 }
  end

  # Catalogue items for the payload's reward ids
  def gacha_banner_items(ids = ORDINARY.map(&:first))
    ids.each_with_index.map do |id, index|
      type = id.start_with?('2') ? 'Summon' : 'Weapon'
      { 'identity' => "#{type}:00000000-0000-0000-0000-#{format('%012d', index)}", 'drawable_type' => type,
        'granblue_id' => id, 'rarity' => id[2].to_i - 1, 'promotions' => [1],
        'name' => { 'en' => id, 'ja' => id }, 'category' => type == 'Summon' ? 'summon' : 'weapon' }
    end
  end
end

RSpec.configure { |config| config.include GachaBannerPayloads }
