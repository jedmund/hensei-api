class Api::V1::SearchController < ApplicationController
    def index
        logger.debug params
        if params[:query].present?
            @weapons = Weapon.search(params[:query])
        else
            @weapons = Weapon.all
        end
    end
end