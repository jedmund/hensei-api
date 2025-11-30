class CreateCollectionJobAccessories < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_job_accessories, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :job_accessory, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end

    add_index :collection_job_accessories, [:user_id, :job_accessory_id],
              unique: true, name: 'idx_collection_job_acc_user_accessory'
  end
end