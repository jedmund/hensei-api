class Api::V1::SearchController < Api::V1::ApiController
    def characters
        locale = params[:locale] || 'en'

        if params[:query].present?
            if locale == 'ja'
                @characters = Character.jp_search(params[:query]).limit(10)
            else
                # @characters = Character.where("name_en ILIKE ? AND name_en NOT ILIKE ALL(ARRAY[?])", "%#{params[:query]}%", excludes).limit(10)
                @characters = Character.en_search(params[:query]).limit(10)
            end
        else
            @characters = Character.all
        end
    end

    def weapons
        locale = params[:locale] || 'en'

        if params[:query].present?
            if locale == 'ja'
                @weapons = Weapon.jp_search(params[:query]).limit(10)
            else
                @weapons = Weapon.en_search(params[:query]).limit(10)
            end
        else
            @weapons = Weapon.all
        end
    end

    def summons
        locale = params[:locale] || 'en'

        if params[:query].present?
            if locale == 'ja'
                @summons = Summon.jp_search(params[:query]).limit(10)
            else
                @summons = Summon.en_search(params[:query]).limit(10)
            end
        else
            @summons = Summon.all
        end
    end
end