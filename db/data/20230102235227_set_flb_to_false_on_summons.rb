# frozen_string_literal: true

class SetFlbToFalseOnSummons < ActiveRecord::Migration[6.1]
  def up
    Summon.all.each do |summon|
      if summon.flb.nil?
        summon.flb = false
        summon.save
      end

      if summon.ulb.nil?
        summon.ulb = false
        summon.save
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
