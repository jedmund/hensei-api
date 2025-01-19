class AddPreviewS3KeyToParties < ActiveRecord::Migration[8.0]
  def change
    add_column :parties, :preview_s3_key, :string
  end
end
