# frozen_string_literal: true

module Api
  module V1
    # The current user's saved sparks. Private to their owner: every lookup is
    # scoped to current_user, so someone else's spark is a 404.
    class SavedSparksController < Api::V1::ApiController
      before_action :restrict_access
      before_action :set_spark, only: %i[show update destroy]

      # GET /sparks
      def index
        sparks = current_user.saved_sparks.newest_first.paginate(page: params[:page], per_page: page_size)

        render json: SavedSparkBlueprint.render(sparks, root: :results, meta: pagination_meta(sparks))
      end

      # GET /sparks/:id
      def show
        render json: SavedSparkBlueprint.render(@spark, root: :spark)
      end

      # POST /sparks
      def create
        spark = current_user.saved_sparks.build(spark_params)

        if spark.save
          render json: SavedSparkBlueprint.render(spark, root: :spark), status: :created
        else
          render_validation_error_response(spark)
        end
      end

      # PATCH /sparks/:id
      def update
        if @spark.update(spark_params)
          render json: SavedSparkBlueprint.render(@spark, root: :spark)
        else
          render_validation_error_response(@spark)
        end
      end

      # DELETE /sparks/:id
      def destroy
        @spark.destroy!
        head :no_content
      end

      private

      def set_spark
        @spark = current_user.saved_sparks.find(params.expect(:id))
      end

      # Not params.expect: it rejects a body holding only the marks, which is a
      # valid update.
      def spark_params
        raw = params.require(:spark)
        raise ActionController::ParameterMissing, :spark unless raw.is_a?(ActionController::Parameters)

        raw.permit(:spark_date, :draws, :pool, :season, characters: [], moons: [], summons: [])
           .merge(sparked_params(raw))
      end

      # The marks arrive as sparked_marks, a list of { column:, index: }, or
      # from older clients as sparked, one mark or null. Read by hand, since a
      # nested permit drops null and an empty list.
      def sparked_params(raw)
        if raw.key?(:sparked_marks)
          marks = raw[:sparked_marks]
          { sparked_marks: marks.is_a?(Array) ? marks.map { |mark| mark_param(mark) } : marks.to_s }
        elsif raw.key?(:sparked)
          mark = raw[:sparked]
          { sparked_marks: mark.nil? ? [] : [mark_param(mark)] }
        else
          {}
        end
      end

      # A mark that isn't { column:, index: } fails validation
      def mark_param(mark)
        return { column: nil, index: nil } unless mark.is_a?(ActionController::Parameters)

        { column: mark[:column].is_a?(String) ? mark[:column] : nil, index: mark[:index] }
      end
    end
  end
end
