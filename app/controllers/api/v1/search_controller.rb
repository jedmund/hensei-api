# frozen_string_literal: true

module Api
  module V1
    class SearchController < Api::V1::ApiController
      TRIGRAM = {
        trigram: {
          threshold: 0.3
        }
      }.freeze

      TSEARCH_WITH_PREFIX = {
        tsearch: {
          prefix: true,
          dictionary: 'simple'
        }
      }.freeze

      def all
        locale = search_params[:locale] || 'en'

        case locale
        when 'en'
          results = search_all_en
        when 'ja'
          results = search_all_ja
        end

        render json: SearchBlueprint.render(results, root: :results)
      end

      def search_all_en
        query = search_params[:query]
        exclude = search_params[:exclude]

        PgSearch.multisearch_options = { using: TRIGRAM }
        results = PgSearch.multisearch(query).where.not(granblue_id: exclude).limit(10)

        if (results.length < 5) && (query.length >= 2)
          PgSearch.multisearch_options = { using: TSEARCH_WITH_PREFIX }
          results = PgSearch.multisearch(query).where.not(granblue_id: exclude).limit(10)
        end

        results
      end

      def search_all_ja
        query = search_params[:query]
        exclude = search_params[:exclude]

        PgSearch.multisearch_options = { using: TSEARCH_WITH_PREFIX }
        PgSearch.multisearch(query).where.not(granblue_id: exclude).limit(10)
      end

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
                         Character.ja_search(search_params[:query]).where(conditions)
                       else
                         Character.en_search(search_params[:query]).where(conditions)
                       end
                     else
                       Character.where(conditions).order(Arel.sql('greatest(release_date, flb_date, ulb_date) desc'))
                     end

        count = characters.length
        paginated = characters.paginate(page: search_params[:page], per_page: SEARCH_PER_PAGE)

        render json: CharacterBlueprint.render(paginated,
                                               root: :results,
                                               meta: {
                                                 count: count,
                                                 total_pages: total_pages(count),
                                                 per_page: SEARCH_PER_PAGE
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
          conditions[:extra] = filters['extra'] unless filters['extra'].blank?
        end

        weapons = if search_params[:query].present? && search_params[:query].length >= 2
                    if locale == 'ja'
                      Weapon.ja_search(search_params[:query]).where(conditions)
                    else
                      Weapon.en_search(search_params[:query]).where(conditions)
                    end
                  else
                    Weapon.where(conditions).order(Arel.sql('greatest(release_date, flb_date, ulb_date, transcendence_date) desc'))
                  end

        count = weapons.length
        paginated = weapons.paginate(page: search_params[:page], per_page: SEARCH_PER_PAGE)

        render json: WeaponBlueprint.render(paginated,
                                            root: :results,
                                            meta: {
                                              count: count,
                                              total_pages: total_pages(count),
                                              per_page: SEARCH_PER_PAGE
                                            })
      end

      def summons
        filters = search_params[:filters]
        locale = search_params[:locale] || 'en'
        conditions = {}

        if filters
          conditions[:rarity] = filters['rarity'] unless filters['rarity'].blank? || filters['rarity'].empty?
          conditions[:element] = filters['element'] unless filters['element'].blank? || filters['element'].empty?
          conditions[:subaura] = filters['subaura'] unless filters['subaura'].blank?
        end

        summons = if search_params[:query].present? && search_params[:query].length >= 2
                    if locale == 'ja'
                      Summon.ja_search(search_params[:query]).where(conditions)
                    else
                      Summon.en_search(search_params[:query]).where(conditions)
                    end
                  else
                    Summon.where(conditions).order(release_date: :desc).order(Arel.sql('greatest(release_date, flb_date, ulb_date, transcendence_date) desc'))
                  end

        count = summons.length
        paginated = summons.paginate(page: search_params[:page], per_page: SEARCH_PER_PAGE)

        render json: SummonBlueprint.render(paginated,
                                            root: :results,
                                            meta: {
                                              count: count,
                                              total_pages: total_pages(count),
                                              per_page: SEARCH_PER_PAGE
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
                   JobSkill.joins(:job)
                           .method("#{locale}_search").call(search_params[:query])
                           .where(conditions)
                           .where(job: job.id, main: false)
                           .or(
                             JobSkill.joins(:job)
                                     .method("#{locale}_search").call(search_params[:query])
                                     .where(conditions)
                                     .where(sub: true)
                                     .where.not(job: job.id)
                           )
                           .or(
                             JobSkill.joins(:job)
                                     .method("#{locale}_search").call(search_params[:query])
                                     .where(conditions)
                                     .where(job: { base_job: job.base_job.id }, emp: true)
                                     .where.not(job: job.id)
                           )
                           .or(
                             JobSkill.joins(:job)
                                     .method("#{locale}_search").call(search_params[:query])
                                     .where(conditions)
                                     .where(job: { base_job: job.base_job.id }, base: true)
                                     .where.not(job: job.id)
                           )
                 else
                   JobSkill.all
                           .joins(:job)
                           .where(conditions)
                           .where(job: job.id, main: false)
                           .or(
                             JobSkill.all
                                     .where(conditions)
                                     .where(sub: true)
                                     .where.not(job: job.id)
                           )
                           .or(
                             JobSkill.all
                                     .where(conditions)
                                     .where(job: job.base_job.id, base: true)
                                     .where.not(job: job.id)
                           )
                           .or(
                             JobSkill.all
                                     .where(conditions)
                                     .joins(:job)
                                     .where(job: { base_job: job.base_job.id }, emp: true)
                                     .where.not(job: job.id)
                           )
                 end

        count = skills.length
        paginated = skills.paginate(page: search_params[:page], per_page: SEARCH_PER_PAGE)

        render json: JobSkillBlueprint.render(paginated,
                                              root: :results,
                                              meta: {
                                                count: count,
                                                total_pages: total_pages(count),
                                                per_page: SEARCH_PER_PAGE
                                              })
      end

      def guidebooks
        # Perform the query
        books = if search_params[:query].present? && search_params[:query].length >= 2
                  Guidebook.method("#{locale}_search").call(search_params[:query])
                else
                  Guidebook.all
                end

        count = books.length
        paginated = books.paginate(page: search_params[:page], per_page: SEARCH_PER_PAGE)

        render json: GuidebookBlueprint.render(paginated,
                                               root: :results,
                                               meta: {
                                                 count: count,
                                                 total_pages: total_pages(count),
                                                 per_page: SEARCH_PER_PAGE
                                               })
      end

      private

      def total_pages(count)
        count.to_f / SEARCH_PER_PAGE > 1 ? (count.to_f / SEARCH_PER_PAGE).ceil : 1
      end

      # Specify whitelisted properties that can be modified.
      def search_params
        params.require(:search).permit!
      end
    end
  end
end
