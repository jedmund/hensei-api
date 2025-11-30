class CollectionJobAccessory < ApplicationRecord
  belongs_to :user
  belongs_to :job_accessory

  validates :job_accessory_id, uniqueness: { scope: :user_id,
    message: "already exists in your collection" }

  scope :by_job, ->(job_id) { joins(:job_accessory).where(job_accessories: { job_id: job_id }) }
  scope :by_job_accessory, ->(job_accessory_id) { where(job_accessory_id: job_accessory_id) }

  def blueprint
    Api::V1::CollectionJobAccessoryBlueprint
  end
end