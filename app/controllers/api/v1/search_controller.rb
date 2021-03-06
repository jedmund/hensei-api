class Api::V1::SearchController < Api::V1::ApiController
    def characters
        if params[:query].present?
            @characters = Character.search(params[:query]).limit(10)
        else
            @characters = Character.all
        end
    end

    def weapons
        if params[:query].present?
            @weapons = Weapon.search(params[:query]).limit(10)
        else
            @weapons = Weapon.all
        end
    end

    def summons
        if params[:query].present?
            @summons = Summon.search(params[:query]).limit(10)
        else
            @summons = Summon.all
        end
    end
end