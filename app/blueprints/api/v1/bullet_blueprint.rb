# frozen_string_literal: true

module Api
  module V1
    class BulletBlueprint < Blueprinter::Base
      identifier :id

      field :name do |b|
        {
          en: b.name_en,
          ja: b.name_jp
        }
      end

      field :effect do |b|
        {
          en: b.effect_en,
          ja: b.effect_jp
        }
      end

      fields :granblue_id, :slug, :bullet_type, :atk, :hits_all, :order
    end
  end
end
