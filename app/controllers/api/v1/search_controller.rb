# frozen_string_literal: true

module Api
  module V1
    class SearchController < Api::V1::ApiController
      rate_limit to: 30, within: 1.minute, by: -> { client_ip }, only: :suggestions,
                 with: -> { render json: { error: 'Rate limit exceeded. Try again later.' }, status: :too_many_requests }

      def all
        render json: SearchBlueprint.render(UnifiedSearchQuery.call(search_params, locale: search_locale),
                                            root: :results)
      end

      def characters
        render_page CharacterSearchQuery.call(search_params, locale: search_locale),
                    CharacterBlueprint, view: :dates, includes: :character_series_records
      end

      def weapons
        render_page WeaponSearchQuery.call(search_params, locale: search_locale),
                    WeaponBlueprint, view: :grid, includes: [
                      :weapon_series, :weapon_series_variant, :base_weapon,
                      { recruited_character: :character_series_records }
                    ]
      end

      def summons
        render_page SummonSearchQuery.call(search_params, locale: search_locale),
                    SummonBlueprint, view: :dates, includes: :summon_series
      end

      def job_skills
        raise Api::V1::NoJobProvidedError if search_params[:job].blank?

        job = Job.find(search_params[:job])
        render_page JobSkillSearchQuery.call(search_params, locale: search_locale, job: job), JobSkillBlueprint
      end

      def suggestions
        count = params[:count].to_i.clamp(1, 30)
        per_type = (count / 3.0).ceil

        characters = Character.order(Arel.sql('RANDOM()')).limit(per_type)
        weapons = Weapon.order(Arel.sql('RANDOM()')).limit(per_type)
        summons = Summon.order(Arel.sql('RANDOM()')).limit(per_type)

        results = (characters + weapons + summons).sample(count).map do |entity|
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
        render_page GuidebookSearchQuery.call(search_params, locale: search_locale), GuidebookBlueprint
      end

      private

      # Specify whitelisted properties that can be modified.
      def search_params
        return {} if params[:search].blank?

        params.require(:search).permit!
      end

      # Normalizes the requested locale to a supported search scope. Clients send
      # either "ja" or "jp" for Japanese; the models define en_search / ja_search
      # and name_en / name_jp. Anything else falls back to English.
      def search_locale
        %w[ja jp].include?(search_params[:locale].to_s) ? 'ja' : 'en'
      end

      # Renders a page of results, with the count of every match in the meta
      def render_page(results, blueprint, includes: [], **)
        count = results.length
        paginated = results.includes(includes).paginate(page: search_params[:page], per_page: search_page_size)

        render json: blueprint.render(paginated, root: :results,
                                                 meta: pagination_meta(paginated).merge(count: count), **)
      end
    end
  end
end
