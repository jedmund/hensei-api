# frozen_string_literal: true

# Spy's Sleeve Dagger was the only item whose English name used a curly
# apostrophe (U+2019). The name uses a straight one like every other item.
# wiki_en keeps the curly one: it's the wiki page's actual title, which is how
# the weapon's wiki page is fetched.
class StraightApostropheSpysSleeveDagger < ActiveRecord::Migration[8.1]
  def up
    updated = Weapon.where(name_en: 'Spy’s Sleeve Dagger').update_all(name_en: "Spy's Sleeve Dagger", updated_at: Time.current)
    say "Spy's Sleeve Dagger renamed: #{updated}"
  end

  def down
    Weapon.where(name_en: "Spy's Sleeve Dagger").update_all(name_en: 'Spy’s Sleeve Dagger', updated_at: Time.current)
  end
end
