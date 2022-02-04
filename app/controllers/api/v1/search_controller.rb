class Api::V1::SearchController < Api::V1::ApiController
    def characters
        if params[:query].present?
            excludes = params[:excludes] ? 
                params[:excludes].split(',').map { |e| "%#{e.gsub(/\([^()]*\)/, '').strip}%" } : ''
            
            @characters = Character.where("name_en ILIKE ? AND name_en NOT ILIKE ALL(ARRAY[?])", "%#{params[:query]}%", excludes).limit(10)
            # @characters = Character.search(query).limit(10)
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
            excludes = params[:excludes] ? params[:excludes].split(',').each { |e| "!#{e}" }.join(' ') : ''
            @summons = Summon.search(params[:query]).limit(10)
        else
            @summons = Summon.all
        end
    end
end