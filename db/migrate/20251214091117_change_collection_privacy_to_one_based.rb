# frozen_string_literal: true

class ChangeCollectionPrivacyToOneBased < ActiveRecord::Migration[8.0]
  def up
    # Shift all values up by 1: 0->1, 1->2, 2->3
    execute 'UPDATE users SET collection_privacy = collection_privacy + 1'

    # Change default from 0 to 1
    change_column_default :users, :collection_privacy, from: 0, to: 1
  end

  def down
    # Shift all values down by 1: 1->0, 2->1, 3->2
    execute 'UPDATE users SET collection_privacy = collection_privacy - 1'

    # Restore default
    change_column_default :users, :collection_privacy, from: 1, to: 0
  end
end
