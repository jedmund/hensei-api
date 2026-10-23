# frozen_string_literal: true

module Api
  module V1
    ##
    # POST /import/wiki: imports a gbf.wiki TeamSpread team that the web app
    # has parsed into titles and identifiers. With `preview: true` it only
    # reports what would import; otherwise it creates the party, owned by the
    # signed-in user or anonymous with an edit key, like PartiesController#create.
    #
    # The work happens in WikiImport::Importer. Both modes answer 200 with
    # `{ party, report }`; `party` is null in a preview.
    class WikiImportController < Api::V1::ApiController
      include SubstituteGridPreloading
      include PartyFullLoading

      # A TeamSpread paste resolves to a few KB of JSON.
      MAX_BODY_BYTES = 64.kilobytes

      limit_requests 'wiki-import', to: 30, within: 1.minute, only: :create

      def create
        if request.raw_post.bytesize > MAX_BODY_BYTES
          return render json: { error: 'payload_too_large' }, status: :payload_too_large
        end

        payload = WikiImport::Payload.parse(parse_body)
        importer = WikiImport::Importer.new(payload, user: current_user)
        return render json: { party: nil, report: importer.preview } if payload.preview

        party, report = importer.create!
        render json: { party: render_party(party), report: report }
      rescue WikiImport::Payload::Invalid => e
        render json: { error: 'invalid_payload', detail: e.message }, status: :unprocessable_content
      end

      private

      def parse_body
        JSON.parse(request.raw_post)
      rescue JSON::ParserError
        raise WikiImport::Payload::Invalid, 'body is not valid JSON'
      end

      # The party exactly as PartiesController#create renders it.
      def render_party(party)
        PartyBlueprint.render_as_hash(load_full_party(party.id), view: :created,
                                                                 current_user: current_user,
                                                                 admin_mode: admin_mode)
      end
    end
  end
end
