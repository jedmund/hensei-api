# frozen_string_literal: true

# Job, JobSkill and JobAccessory validate these; enforce them in the database too.
# A Class I job and its Class II successor share a granblue_id, so job ids are
# unique per row; a skill several jobs share has one slug, so slugs are unique
# per job. The skills index leads with job_id, so it replaces the plain one.
class MakeJobCatalogueIdsUnique < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :jobs, %i[granblue_id row], unique: true, algorithm: :concurrently
    add_index :job_accessories, :granblue_id, unique: true, algorithm: :concurrently
    add_index :job_skills, %i[job_id slug], unique: true, algorithm: :concurrently
    remove_index :job_skills, :job_id, name: 'index_job_skills_on_job_id', algorithm: :concurrently
  end

  def down
    add_index :job_skills, :job_id, name: 'index_job_skills_on_job_id', algorithm: :concurrently
    remove_index :job_skills, %i[job_id slug], algorithm: :concurrently
    remove_index :job_accessories, :granblue_id, algorithm: :concurrently
    remove_index :jobs, %i[granblue_id row], algorithm: :concurrently
  end
end
