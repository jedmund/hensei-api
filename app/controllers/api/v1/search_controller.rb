class Api::V1::SearchController < Api::V1::ApiController
    def characters
        filters = search_params[:filters]
        locale = search_params[:locale] || 'en'
        conditions = {}

        if filters
            conditions[:rarity] = filters['rarity'] unless filters['rarity'].blank? || filters['rarity'].empty?
            conditions[:element] = filters['element'] unless filters['element'].blank? || filters['element'].empty?
            conditions[:proficiency1] = filters['proficiency1'] unless filters['proficiency1'].blank? || filters['proficiency1'].empty?
            conditions[:proficiency2] = filters['proficiency2'] unless filters['proficiency2'].blank? || filters['proficiency2'].empty?
            # conditions[:series] = filters['series'] unless filters['series'].blank? || filters['series'].empty?
        end

        if search_params[:query].present? && search_params[:query].length >= 2
            if locale == 'ja'
                @characters = Character.jp_search(search_params[:query]).where(conditions)
            else
                @characters = Character.en_search(search_params[:query]).where(conditions)
            end  
        else
            @characters = Character.where(conditions)
        end

        @count = @characters.length
        @characters = @characters.paginate(page: search_params[:page], per_page: 10)
    end

    def weapons
        filters = search_params[:filters]
        locale = search_params[:locale] || 'en'
        conditions = {}

        if filters
            conditions[:rarity] = filters['rarity'] unless filters['rarity'].blank? || filters['rarity'].empty?
            conditions[:element] = filters['element'] unless filters['element'].blank? || filters['element'].empty?
            conditions[:proficiency] = filters['proficiency1'] unless filters['proficiency1'].blank? || filters['proficiency1'].empty?
            conditions[:series] = filters['series'] unless filters['series'].blank? || filters['series'].empty?
        end

        if search_params[:query].present? && search_params[:query].length >= 2
            if locale == 'ja'
                @weapons = Weapon.jp_search(search_params[:query]).where(conditions)
            else
                @weapons = Weapon.en_search(search_params[:query]).where(conditions)
            end  
        else
            @weapons = Weapon.where(conditions)
        end

        @count = @weapons.length
        @weapons = @weapons.paginate(page: search_params[:page], per_page: 10)
    end

    def summons
        filters = search_params[:filters]
        locale = search_params[:locale] || 'en'
        conditions = {}

        if filters
            conditions[:rarity] = filters['rarity'] unless filters['rarity'].blank? || filters['rarity'].empty?
            conditions[:element] = filters['element'] unless filters['element'].blank? || filters['element'].empty?
        end

        if search_params[:query].present? && search_params[:query].length >= 2
            if locale == 'ja'
                @summons = Summon.jp_search(search_params[:query]).where(conditions)
            else
                @summons = Summon.en_search(search_params[:query]).where(conditions)
            end  
        else
            @summons = Summon.where(conditions)
        end

        @count = @summons.length
        @summons = @summons.paginate(page: search_params[:page], per_page: 10)
    end

    private

    # Specify whitelisted properties that can be modified.
    def search_params
        params.require(:search).permit!
    end
end