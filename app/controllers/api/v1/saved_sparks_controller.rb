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

      # Not params.expect: it rejects a body holding only `sparked`, which is a
      # valid update.
      def spark_params
        raw = params.require(:spark)
        raise ActionController::ParameterMissing, :spark unless raw.is_a?(ActionController::Parameters)

        raw.permit(:spark_date, :draws, :pool, :season, characters: [], moons: [], summons: [])
           .merge(sparked_params(raw))
      end

      # The mark arrives as { column:, index: } or null. A nested permit would
      # drop null, and null is how the client clears the mark.
      def sparked_params(raw)
        return {} unless raw.key?(:sparked)

        mark = raw[:sparked]
        return { sparked_column: nil, sparked_index: nil } if mark.nil?
        # Anything else fails validation (a column without an index)
        return { sparked_column: '', sparked_index: nil } unless mark.is_a?(ActionController::Parameters)

        column = mark[:column]
        index = mark[:index]
        {
          sparked_column: column.is_a?(String) ? column : '',
          sparked_index: index.is_a?(Integer) || index.to_s.match?(/\A\d+\z/) ? index.to_i : nil
        }
      end
    end
  end
end
