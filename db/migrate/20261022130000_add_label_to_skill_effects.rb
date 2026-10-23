# frozen_string_literal: true

# The skill's own name for a status the wiki list links to another (D57): Ayer's "Guilty Break" is
# a Jammed effect, and keeps its name for display. Null when the mention names the status itself.
class AddLabelToSkillEffects < ActiveRecord::Migration[8.1]
  def change
    add_column :skill_effects, :label, :string
  end
end
