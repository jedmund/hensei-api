# frozen_string_literal: true

# Lecia's style shift (碧の継承者 / Inheritor of the Blue Mantle) has no Japanese skill text:
# no gbf-wiki.com page or section covers it and there's no game_raw_jp yet (D38). The
# official blog's introduction gives each skill's name and effect line; this stores them as
# the style row's jp_skill_text source, which the build applies after the JP wiki (game data
# still wins). Writing it queues the row's build.
#
# Slots follow the style row's wikitext order (a1–a3, ougi, s1–s2), one version each. The
# ougi's description is the blog's first line; its Lv 5 note (秩序の凱旋Lv5: 碧の鎧) is left out.
# Idempotent (Source.put writes only a changed body); no-op if the row isn't there.
class AddLeciaStyleJpSkillText < ActiveRecord::Migration[8.1]
  GRANBLUE_ID = '3040101000'
  TEXT = {
    'source' => 'official blog, Lecia style shift intro',
    'skills' => [
      { 'kind' => 'ability', 'position' => 1, 'name_jp' => 'ソニックバースト',
        'description_jp' => '敵に2回風属性ダメージ/風属性防御DOWN(累積)/自分のトリプルアタック確率UP(累積)' },
      { 'kind' => 'ability', 'position' => 2, 'name_jp' => 'ウインドベール',
        'description_jp' => '風属性キャラに弱体効果無効(1回)/土属性ダメージを軽減/被ダメージを土属性に変換/再生効果' },
      { 'kind' => 'ability', 'position' => 3, 'name_jp' => '碧の剣風',
        'description_jp' => '碧の鎧を消費して敵全体に風属性ダメージ/風属性キャラの攻撃大幅UP(1回)/風属性追撃効果' },
      { 'kind' => 'ougi', 'position' => 1, 'name_jp' => 'トワイライトソード・リユニオン',
        'description_jp' => '風属性ダメージ(特大)/ウインドベールの再使用間隔を1ターン短縮' },
      { 'kind' => 'support', 'position' => 1, 'name_jp' => '秩序の騎空団総団長',
        'description_jp' => '得意武器「剣」の風属性キャラが累計でトリプルアタックを5回発動する度にソニックバーストが発動/' \
                            '自分の秩序の凱旋Lvが1上昇(最大5)' },
      { 'kind' => 'support', 'position' => 2, 'name_jp' => '碧の鎧',
        'description_jp' => 'バトル開始時、自分に碧の鎧効果' }
    ]
  }.freeze

  def up
    character = Character.find_by(granblue_id: GRANBLUE_ID, style_swap: true)
    return say("Lecia's style row (#{GRANBLUE_ID}, style 2) isn't here; nothing stored") unless character

    result = Source.put(character, :jp_skill_text, TEXT, fetched_at: nil)
    say "Lecia style jp_skill_text: #{result.status}"
  end

  def down
    character = Character.find_by(granblue_id: GRANBLUE_ID, style_swap: true)
    Source.put(character, :jp_skill_text, nil) if character
  end
end
