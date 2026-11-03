# frozen_string_literal: true

# Gauph Key of Strength and Gauph Key of Zeal are Normal-frame Stamina/Enmity per
# gbf.wiki (unboosted: Ultima isn't summon-boosted), not EX. Tagged EX, they showed
# as a second "Stamina"/"Enmity" line instead of adding to the grid's normal one
# (user report, DkQurT). Gauph Key of Will stays EX ATK.
class MoveGauphStatKeysToNormalFrame < ActiveRecord::Migration[8.0]
  KEYS = {
    'gauph-strength' => 'stamina',
    'gauph-zeal' => 'enmity'
  }.freeze

  def up
    move_to('normal', from: 'ex')
  end

  def down
    move_to('ex', from: 'normal')
  end

  private

  def move_to(series, from:)
    KEYS.each do |slug, boost_type|
      WeaponSkillEffect.where(key_slug: slug, boost_type: boost_type, series: from)
                       .find_each { |effect| effect.update!(series: series) }
    end
  end
end
