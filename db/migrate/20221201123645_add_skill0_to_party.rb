class AddSkill0ToParty < ActiveRecord::Migration[6.1]
  def change
    change_table(:parties) do |t|
      t.references :skill0, type: :uuid, foreign_key: { to_table: "job_skills" }
    end
  end
end
