class Api::V1::SearchController < Api::V1::ApiController
    def index
        logger.debug params
        if params[:query].present?
            @weapons = Weapon.search(params[:query]).limit(10)
        else
            @weapons = Weapon.all
        end
    end
end