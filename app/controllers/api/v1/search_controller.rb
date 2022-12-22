# frozen_string_literal: true

module Api
  module V1
    PER_PAGE = 10

    class SearchController < Api::V1::ApiController
      def characters
        filters = search_params[:filters]
        locale = search_params[:locale] || 'en'
        conditions = {}

        if filters
          conditions[:rarity] = filters['rarity'] unless filters['rarity'].blank? || filters['rarity'].empty?
          conditions[:element] = filters['element'] unless filters['element'].blank? || filters['element'].empty?
          unless filters['proficiency1'].blank? || filters['proficiency1'].empty?
            conditions[:proficiency1] =
              filters['proficiency1']
          end
          unless filters['proficiency2'].blank? || filters['proficiency2'].empty?
            conditions[:proficiency2] =
              filters['proficiency2']
          end
          # conditions[:series] = filters['series'] unless filters['series'].blank? || filters['series'].empty?
        end

        characters = if search_params[:query].present? && search_params[:query].length >= 2
                       if locale == 'ja'
                         Character.jp_search(search_params[:query]).where(conditions)
                       else
                         Character.en_search(search_params[:query]).where(conditions)
                       end
                     else
                       Character.where(conditions)
                     end

        count = characters.length
        paginated = characters.paginate(page: search_params[:page], per_page: PER_PAGE)

        render json: CharacterBlueprint.render(paginated, meta: {
                                                 count: count,
                                                 total_pages: total_pages(count)
                                               })
      end

      def weapons
        filters = search_params[:filters]
        locale = search_params[:locale] || 'en'
        conditions = {}

        if filters
          conditions[:rarity] = filters['rarity'] unless filters['rarity'].blank? || filters['rarity'].empty?
          conditions[:element] = filters['element'] unless filters['element'].blank? || filters['element'].empty?
          unless filters['proficiency1'].blank? || filters['proficiency1'].empty?
            conditions[:proficiency] =
              filters['proficiency1']
          end
          conditions[:series] = filters['series'] unless filters['series'].blank? || filters['series'].empty?
        end

        weapons = if search_params[:query].present? && search_params[:query].length >= 2
                    if locale == 'ja'
                      Weapon.jp_search(search_params[:query]).where(conditions)
                    else
                      Weapon.en_search(search_params[:query]).where(conditions)
                    end
                  else
                    Weapon.where(conditions)
                  end

        count = weapons.length
        paginated = weapons.paginate(page: search_params[:page], per_page: PER_PAGE)

        render json: WeaponBlueprint.render(paginated, meta: {
                                              count: count,
                                              total_pages: total_pages(count)
                                            })
      end

      def summons
        filters = search_params[:filters]
        locale = search_params[:locale] || 'en'
        conditions = {}

        if filters
          conditions[:rarity] = filters['rarity'] unless filters['rarity'].blank? || filters['rarity'].empty?
          conditions[:element] = filters['element'] unless filters['element'].blank? || filters['element'].empty?
        end

        summons = if search_params[:query].present? && search_params[:query].length >= 2
                    if locale == 'ja'
                      Summon.jp_search(search_params[:query]).where(conditions)
                    else
                      Summon.en_search(search_params[:query]).where(conditions)
                    end
                  else
                    Summon.where(conditions)
                  end

        count = summons.length
        paginated = summons.paginate(page: search_params[:page], per_page: PER_PAGE)

        render json: SummonBlueprint.render(paginated, meta: {
                                              count: count,
                                              total_pages: total_pages(count)
                                            })
      end

      def job_skills
        raise Api::V1::NoJobProvidedError unless search_params[:job].present?

        # Set up basic parameters we'll use
        job = Job.find(search_params[:job])
        locale = search_params[:locale] || 'en'

        # Set the conditions based on the group requested
        conditions = {}
        if search_params[:filters].present? && search_params[:filters]['group'].present?
          group = search_params[:filters]['group'].to_i

          if group >= 0 && group < 4
            conditions[:color] = group
            conditions[:emp] = false
            conditions[:base] = false
          elsif group == 4
            conditions[:emp] = true
          elsif group == 5
            conditions[:base] = true
          end
        end

        # Perform the query
        skills = if search_params[:query].present? && search_params[:query].length >= 2
                   JobSkill.method("#{locale}_search").call(search_params[:query])
                           .where(conditions)
                           .where(job: job.id, main: false)
                           .or(
                             JobSkill.method("#{locale}_search").call(search_params[:query])
                                     .where(conditions)
                                     .where(sub: true)
                           )
                 else
                   JobSkill.all
                           .where(conditions)
                           .where(job: job.id, main: false)
                           .or(
                             JobSkill.all
                                     .where(conditions)
                                     .where(sub: true)
                           )
                           .or(
                             JobSkill.all
                                     .where(conditions)
                                     .where(job: job.base_job.id, base: true)
                                     .where.not(job: job.id)
                           )
                 end

        count = skills.length
        paginated = skills.paginate(page: search_params[:page], per_page: PER_PAGE)

        render json: JobSkillBlueprint.render(paginated, meta: {
                                                count: count,
                                                total_pages: total_pages(count)
                                              })
      end

      private

      def total_pages(count)
        count.to_f / PER_PAGE > 1 ? (count.to_f / PER_PAGE).ceil : 1
      end

      # Specify whitelisted properties that can be modified.
      def search_params
        params.require(:search).permit!
      end
    end
  end
end
