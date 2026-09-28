# frozen_string_literal: true

# weapons.ax_type only ever held a bogus 'utility' value on the six Ancient weapons
# (cleared by the 20260927120000 data migration). AX profiles are derived from the
# weapon series (Weapon#effective_ax_type), so the column is unused.
class RemoveAxTypeFromWeapons < ActiveRecord::Migration[8.0]
  def change
    remove_column :weapons, :ax_type, :string
  end
end
