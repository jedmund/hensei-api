# frozen_string_literal: true

module Api
  module V1
    class SearchController < Api::V1::ApiController
      rate_limit to: 30, within: 1.minute, by: -> { request.remote_ip }, only: :suggestions,
                 with: -> { render json: { error: "Rate limit exceeded. Try again later." }, status: :too_many_requests }

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
        exclude = search_params[:exclude]
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
          conditions[:season] = filters['season'] unless filters['season'].blank? || filters['season'].empty?
        end

        characters = if search_params[:query].present? && search_params[:query].length >= 2
                       if locale == 'ja'
                         Character.ja_search(search_params[:query]).where(conditions)
                       else
                         Character.en_search(search_params[:query]).where(conditions)
                       end
                     else
                       Character.where(conditions)
                     end

        # Apply sorting if specified, otherwise use default
        if search_params[:sort].present?
          characters = apply_sort(characters, search_params[:sort], search_params[:order], locale)
        elsif search_params[:query].blank?
          characters = characters.order(Arel.sql('greatest(release_date, flb_date, ulb_date) desc, id asc'))
        end

        # Filter by series (array overlap)
        if filters && filters['series'].present? && !filters['series'].empty?
          series_values = Array(filters['series']).map(&:to_i)
          characters = characters.where('series && ARRAY[?]::integer[]', series_values)
        end

        # Exclude already-owned characters (for collection modal)
        if exclude.present? && exclude.any?
          characters = characters.where.not(id: exclude)
        end

        count = characters.length
        paginated = characters.includes(:character_series_records)
                              .paginate(page: search_params[:page], per_page: search_page_size)

        render json: CharacterBlueprint.render(paginated,
                                               view: :dates,
                                               root: :results,
                                               meta: pagination_meta(paginated).merge(count: count))
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
          conditions[:weapon_series_id] = filters['series'] unless filters['series'].blank? || filters['series'].empty?
          conditions[:extra] = filters['extra'] unless filters['extra'].blank?
        end

        weapons = if search_params[:query].present? && search_params[:query].length >= 2
                    if locale == 'ja'
                      Weapon.ja_search(search_params[:query]).where(conditions)
                    else
                      Weapon.en_search(search_params[:query]).where(conditions)
                    end
                  else
                    Weapon.where(conditions)
                  end

        # Apply sorting if specified, otherwise use default
        if search_params[:sort].present?
          weapons = apply_sort(weapons, search_params[:sort], search_params[:order], locale)
        elsif search_params[:query].blank?
          weapons = weapons.order(Arel.sql('greatest(release_date, flb_date, ulb_date, transcendence_date) desc, id asc'))
        end

        # Filter by promotions (array overlap)
        if filters && filters['promotions'].present? && !filters['promotions'].empty?
          promotions_values = Array(filters['promotions']).map(&:to_i)
          weapons = weapons.where('promotions && ARRAY[?]::integer[]', promotions_values)
        end

        count = weapons.length
        paginated = weapons.includes(:weapon_series, :weapon_series_variant, :base_weapon, :recruited_character).paginate(page: search_params[:page], per_page: search_page_size)

        render json: WeaponBlueprint.render(paginated,
                                            view: :grid,
                                            root: :results,
                                            meta: pagination_meta(paginated).merge(count: count))
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
                    Summon.where(conditions)
                  end

        # Apply sorting if specified, otherwise use default
        if search_params[:sort].present?
          summons = apply_sort(summons, search_params[:sort], search_params[:order], locale)
        elsif search_params[:query].blank?
          summons = summons.order(Arel.sql('greatest(release_date, flb_date, ulb_date, transcendence_date) desc, id asc'))
        end

        # Filter by promotions (array overlap)
        if filters && filters['promotions'].present? && !filters['promotions'].empty?
          promotions_values = Array(filters['promotions']).map(&:to_i)
          summons = summons.where('promotions && ARRAY[?]::integer[]', promotions_values)
        end

        count = summons.length
        paginated = summons.includes(:summon_series).paginate(page: search_params[:page], per_page: search_page_size)

        render json: SummonBlueprint.render(paginated,
                                            view: :dates,
                                            root: :results,
                                            meta: pagination_meta(paginated).merge(count: count))
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
        paginated = skills.paginate(page: search_params[:page], per_page: search_page_size)

        render json: JobSkillBlueprint.render(paginated,
                                              root: :results,
                                              meta: pagination_meta(paginated).merge(count: count))
      end

      def jobs
        filters = search_params[:filters]
        locale = search_params[:locale] || 'en'
        conditions = {}

        if filters
          conditions[:row] = filters['row'] unless filters['row'].blank? || filters['row'].empty?
          unless filters['proficiency'].blank? || filters['proficiency'].empty?
            # Filter by either proficiency1 or proficiency2 matching
            proficiency_values = Array(filters['proficiency']).map(&:to_i)
            conditions[:proficiency1] = proficiency_values
          end
        end

        jobs = if search_params[:query].present? && search_params[:query].length >= 2
                 if locale == 'ja'
                   Job.ja_search(search_params[:query]).where(conditions)
                 else
                   Job.en_search(search_params[:query]).where(conditions)
                 end
               else
                 Job.where(conditions)
               end

        # Filter by proficiency2 as well (OR condition)
        if filters && filters['proficiency'].present? && !filters['proficiency'].empty?
          proficiency_values = Array(filters['proficiency']).map(&:to_i)
          jobs = jobs.or(Job.where(proficiency2: proficiency_values))
        end

        # Apply feature filters
        if filters
          jobs = jobs.where(master_level: true) if filters['masterLevel'] == true || filters['masterLevel'] == 'true'
          jobs = jobs.where(ultimate_mastery: true) if filters['ultimateMastery'] == true || filters['ultimateMastery'] == 'true'
          jobs = jobs.where(accessory: true) if filters['accessory'] == true || filters['accessory'] == 'true'
        end

        # Apply sorting if specified, otherwise use default (row, then order)
        if search_params[:sort].present?
          jobs = apply_job_sort(jobs, search_params[:sort], search_params[:order], locale)
        else
          jobs = jobs.order(:row, :order)
        end

        count = jobs.length
        paginated = jobs.paginate(page: search_params[:page], per_page: search_page_size)

        render json: JobBlueprint.render(paginated,
                                         root: :results,
                                         meta: pagination_meta(paginated).merge(count: count))
      end

      def suggestions
        count = [[params[:count].to_i, 1].max, 30].min
        per_type = (count / 3.0).ceil

        characters = Character.order(Arel.sql('RANDOM()')).limit(per_type)
        weapons = Weapon.order(Arel.sql('RANDOM()')).limit(per_type)
        summons = Summon.order(Arel.sql('RANDOM()')).limit(per_type)

        results = (characters + weapons + summons).shuffle.first(count).map do |entity|
          {
            id: entity.id,
            granblue_id: entity.granblue_id,
            name: { en: entity.name_en, ja: entity.name_jp },
            element: entity.element,
            type: entity.class.name.downcase
          }
        end

        render json: { suggestions: results }
      end

      def guidebooks
        # Perform the query
        books = if search_params[:query].present? && search_params[:query].length >= 2
                  Guidebook.method("#{locale}_search").call(search_params[:query])
                else
                  Guidebook.all
                end

        count = books.length
        paginated = books.paginate(page: search_params[:page], per_page: search_page_size)

        render json: GuidebookBlueprint.render(paginated,
                                               root: :results,
                                               meta: pagination_meta(paginated).merge(count: count))
      end

      private

      # Specify whitelisted properties that can be modified.
      def search_params
        return {} unless params[:search].present?
        params.require(:search).permit!
      end

      # Apply sorting based on column name and order
      def apply_sort(scope, column, order, locale)
        sort_dir = order == 'desc' ? :desc : :asc

        case column
        when 'name'
          name_col = locale == 'ja' ? :name_ja : :name_en
          scope.order(name_col => sort_dir, id: :asc)
        when 'element'
          scope.order(element: sort_dir, id: :asc)
        when 'rarity'
          scope.order(rarity: sort_dir, id: :asc)
        when 'last_updated'
          scope.order(Arel.sql("greatest(release_date, flb_date, ulb_date, transcendence_date) #{sort_dir}, id asc"))
        else
          scope
        end
      end

      # Apply sorting for jobs
      def apply_job_sort(scope, column, order, locale)
        sort_dir = order == 'desc' ? :desc : :asc

        case column
        when 'name'
          name_col = locale == 'ja' ? :name_ja : :name_en
          scope.order(name_col => sort_dir, id: :asc)
        when 'row'
          scope.order(row: sort_dir, order: :asc, id: :asc)
        when 'proficiency'
          scope.order(proficiency1: sort_dir, id: :asc)
        else
          scope.order(:row, :order, :id)
        end
      end
    end
  end
end
