class AddVisibilityToParties < ActiveRecord::Migration[7.0]
  def change
    # -1 = Private
    # 0 = Unlisted
    # 1 = Public
    add_column :parties, :visibility, :integer, default: 1, null: false
  end
end
