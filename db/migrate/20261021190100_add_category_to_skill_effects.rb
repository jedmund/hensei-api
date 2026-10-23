# frozen_string_literal: true

# Buff or debuff belongs to the skill effect, not the status (D36): the game colours the same
# status per skill (Clarisse (Light)'s self-inflicted Hostility is a debuff, Seox's a buff). The
# build fills skill_effects.category; statuses.category becomes the status's usual category and
# statuses.mixed says its effects split.
class AddCategoryToSkillEffects < ActiveRecord::Migration[8.1]
  def change
    add_column :skill_effects, :category, :string
    add_column :statuses, :mixed, :boolean, null: false, default: false
  end
end
