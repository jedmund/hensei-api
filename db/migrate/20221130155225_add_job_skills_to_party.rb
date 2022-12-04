class AddJobSkillsToParty < ActiveRecord::Migration[6.1]
  def change
    change_table(:parties) do |t|
      t.references :skill1, type: :uuid, foreign_key: { to_table: 'job_skills' }
      t.references :skill2, type: :uuid, foreign_key: { to_table: 'job_skills' }
      t.references :skill3, type: :uuid, foreign_key: { to_table: 'job_skills' }
    end
  end
end
