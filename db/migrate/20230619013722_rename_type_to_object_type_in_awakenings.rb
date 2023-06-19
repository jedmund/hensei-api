class RenameTypeToObjectTypeInAwakenings < ActiveRecord::Migration[7.0]
  def change
    rename_column :awakenings, :type, :object_type
  end
end
