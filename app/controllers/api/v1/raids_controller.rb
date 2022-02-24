class Api::V1::RaidsController < Api::V1::ApiController
    def all
        @raids = Raid.all()
        render :all, status: :ok
    end
end