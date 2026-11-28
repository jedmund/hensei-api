# frozen_string_literal: true

module Api
  module V1
    # A saved spark, shaped like the spark maker's Spark (spark.ts) plus its
    # date. spark_date is a plain YYYY-MM-DD day, with no time zone.
    class SavedSparkBlueprint < ApiBlueprint
      field :spark_date do |spark|
        spark.spark_date&.iso8601
      end

      fields :draws, :pool, :season, :characters, :moons, :summons

      field :sparked_marks, &:sparked_marks

      # The first mark, for clients that know only one (until hensei-web reads
      # sparked_marks)
      field :sparked, &:sparked

      fields :created_at, :updated_at
    end
  end
end
