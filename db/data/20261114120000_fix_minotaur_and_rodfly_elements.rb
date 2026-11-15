# frozen_string_literal: true

# Fixes two summons whose element disagrees with their aura (GBF-53), checked in game.
#
# - Minotaur is Fire and boosts Fire. The summon was stored as Wind; its wiki page and
#   aura rows already say Fire, so only summons.element changes.
# - Rodfly is Wind and boosts Wind. Its element is right, but its stored wiki page was
#   Rivacuda's (Water aura, id 2020023000), so the build wrote Water aura rows. This
#   stores Rodfly's own page as fetched from gbf.wiki on 2026-11-14.
#
# Both summons' build fingerprints change, so the deploy's aura build rebuilds them right
# after this migration; no build is queued from here. Rerunnable: each step only matches
# the wrong value.
class FixMinotaurAndRodflyElements < ActiveRecord::Migration[8.1]
  MINOTAUR = '2020012000'
  RODFLY = '2020026000'
  FIRE = 1
  WIND = 4

  RODFLY_PAGE = <<~WIKI
    {{Summon
    |id=2020026000
    |summonid=1037
    |element=wind
    |rarity=r
    |name={{PAGENAME}}
    |jpname=ロッド
    |base_evo=3
    |max_evo=3
    |image={{PAGENAME}}
    |hp1=54
    |hp2=330
    |atk1=120
    |atk2=713
    |release_date=2014-06-17
    |obtain=premium,normal
    |join=[[Premium Draw]]
    |aura_name=Rodfly's Aura
    |aura1=10% boost to Wind [[Damage Formula|Elemental]] ATK.
    |aura2=15% boost to Wind [[Damage Formula|Elemental]] ATK.
    |call_name=Rodfly's Call
    |call_cd=7
    |call_base=Medium Wind damage to all foes.
    |call_mlb=
    |combo1=Body
    |combo2=Slam
    |flavor=The rodfly is a speedy airborne predator whose body is covered in eyes to monitor for potential meals.
    |reduce=N/A
    }}
  WIKI

  def up
    Summon.without_aura_build do
      fixed = Summon.where(granblue_id: MINOTAUR, element: WIND).update_all(element: FIRE)
      say "Minotaur element set to Fire: #{fixed}"

      rodfly = Summon.find_by(granblue_id: RODFLY)
      if rodfly && rodfly.wiki_raw != RODFLY_PAGE
        rodfly.update!(wiki_raw: RODFLY_PAGE, wiki_raw_fetched_at: Time.utc(2026, 11, 14))
        say 'Rodfly wiki page replaced'
      else
        say 'Rodfly wiki page unchanged'
      end
    end
  end

  def down
    # Nothing to undo: both summons now match the game.
  end
end
