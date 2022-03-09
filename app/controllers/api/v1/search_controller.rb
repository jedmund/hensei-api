class Api::V1::SearchController < Api::V1::ApiController
    def characters
        locale = search_params[:locale] || 'en'

        if search_params[:query].present?
            if locale == 'ja'
                @characters = Character.jp_search(search_params[:query]).limit(10)
            else
                # @characters = Character.where("name_en ILIKE ? AND name_en NOT ILIKE ALL(ARRAY[?])", "%#{params[:query]}%", excludes).limit(10)
                @characters = Character.en_search(search_params[:query]).limit(10)
            end
        else
            @characters = Character.all
        end
    end

    def weapons
        filters = search_params[:filters]
        locale = search_params[:locale] || 'en'

        conditions = {}
        conditions[:rarity] = filters['rarity'] unless filters['rarity'].blank? || filters['rarity'].empty?
        conditions[:element] = filters['element'] unless filters['element'].blank? || filters['element'].empty?
        conditions[:proficiency] = filters['proficiency'] unless filters['proficiency'].blank? || filters['proficiency'].empty?
        conditions[:series] = filters['series'] unless filters['series'].blank? || filters['series'].empty?

        ap conditions

        if search_params[:query].present?
            if locale == 'ja'
                @weapons = Weapon.jp_search(search_params[:query]).where(conditions).limit(10)
            else
                @weapons = Weapon.en_search(search_params[:query]).where(conditions).limit(10)
            end  
        else
            @weapons = Weapon.where(conditions).limit(10) # Temporary limit before pagination
        end
    end

    def summons
        locale = search_params[:locale] || 'en'

        if search_params[:query].present?
            if locale == 'ja'
                @summons = Summon.jp_search(search_params[:query]).limit(10)
            else
                @summons = Summon.en_search(search_params[:query]).limit(10)
            end
        else
            @summons = Summon.all
        end
    end

    private

    # Specify whitelisted properties that can be modified.
    def search_params
        params.require(:search).permit!
    end
end