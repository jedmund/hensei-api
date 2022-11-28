class Api::V1::JobsController < Api::V1::ApiController
    def all
        @jobs = Job.all()
        render :all, status: :ok
    end
end
