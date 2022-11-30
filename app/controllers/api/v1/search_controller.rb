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

    def job_skills
        raise Api::V1::NoJobProvidedError unless search_params[:job].present?

        # Set up basic parameters we'll use
        job = Job.find(search_params[:job])
        locale = search_params[:locale] || 'en'

        # Set the conditions based on the group requested
        conditions = {}
        if search_params[:filters].present? && search_params[:filters]["group"].present?
            group = search_params[:filters]["group"].to_i

            if (group < 4)
                conditions[:color] = group
                conditions[:emp] = false
                conditions[:base] = false
            elsif (group == 4)
                conditions[:emp] = true
            elsif (group == 5)
                conditions[:base] = true
            end
        end

        # Perform the query
        if search_params[:query].present? && search_params[:query].length >= 2
            @skills = JobSkill.method("#{locale}_search").(search_params[:query])
                .where(conditions)
                .where(job: job.id, main: false)
                .or(
                    JobSkill.method("#{locale}_search").(search_params[:query])
                    .where(conditions)
                    .where(sub: true)
                )
        else
            @skills = JobSkill.all
                .where(conditions)
                .where(job: job.id, main: false)
                .or(
                    JobSkill.all
                    .where(conditions)
                    .where(sub:true)
                )
        end        

        @count = @skills.length
        @skills = @skills.paginate(page: search_params[:page], per_page: 10)
    end

    private

    # Specify whitelisted properties that can be modified.
    def search_params
        params.require(:search).permit!
    end
end
