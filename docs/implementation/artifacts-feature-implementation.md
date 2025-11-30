# Artifacts Feature Implementation Guide

## Overview

This document provides step-by-step instructions for implementing the Artifacts collection tracking feature. Artifacts are character equipment that users can record in their collection and equip to characters in parties.

## Implementation Steps

### Phase 1: Database Setup

#### 1.1 Create Artifacts Tables Migration

```bash
rails generate migration CreateArtifactsSystem
```

```ruby
# db/migrate/xxx_create_artifacts_system.rb
class CreateArtifactsSystem < ActiveRecord::Migration[8.0]
  def change
    # Canonical artifact data
    create_table :artifacts, id: :uuid do |t|
      t.string :name_en, null: false
      t.string :name_jp, null: false
      t.integer :series
      t.integer :weapon_specialty
      t.integer :rarity, null: false # 3=R, 4=SR, 5=SSR
      t.boolean :is_quirk, default: false
      t.integer :max_level, null: false # 150 for standard, 200 for quirk
      t.timestamps

      t.index :rarity
      t.index :is_quirk
      t.index :weapon_specialty
    end

    # Canonical skill data
    create_table :artifact_skills, id: :uuid do |t|
      t.string :name_en, null: false
      t.string :name_jp, null: false
      t.integer :skill_group, null: false # 1=Group I, 2=Group II, 3=Group III
      t.string :effect_type
      t.integer :max_level, null: false, default: 15
      t.text :description_en
      t.text :description_jp
      t.timestamps

      t.index :skill_group
      t.index :effect_type
    end
  end
end
```

#### 1.2 Create Collection Artifacts Migration

```bash
rails generate migration CreateCollectionArtifacts
```

```ruby
# db/migrate/xxx_create_collection_artifacts.rb
class CreateCollectionArtifacts < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_artifacts, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.uuid :artifact_id, null: false
      t.integer :level, null: false, default: 1

      # Skill slots
      t.uuid :skill1_id
      t.integer :skill1_level, default: 1
      t.uuid :skill2_id
      t.integer :skill2_level, default: 1
      t.uuid :skill3_id
      t.integer :skill3_level, default: 1
      t.uuid :skill4_id # Only for quirk artifacts
      t.integer :skill4_level, default: 1

      t.timestamps

      t.index :user_id
      t.index :artifact_id
      t.index [:user_id, :artifact_id]
    end

    add_foreign_key :collection_artifacts, :users
    add_foreign_key :collection_artifacts, :artifacts
    add_foreign_key :collection_artifacts, :artifact_skills, column: :skill1_id
    add_foreign_key :collection_artifacts, :artifact_skills, column: :skill2_id
    add_foreign_key :collection_artifacts, :artifact_skills, column: :skill3_id
    add_foreign_key :collection_artifacts, :artifact_skills, column: :skill4_id
  end
end
```

#### 1.3 Create Grid Artifacts Migration

```bash
rails generate migration CreateGridArtifacts
```

```ruby
# db/migrate/xxx_create_grid_artifacts.rb
class CreateGridArtifacts < ActiveRecord::Migration[8.0]
  def change
    create_table :grid_artifacts, id: :uuid do |t|
      t.uuid :party_id, null: false
      t.uuid :grid_character_id, null: false

      # Reference to collection
      t.uuid :collection_artifact_id

      # Quick-build fields (when not using collection)
      t.uuid :artifact_id
      t.integer :level, default: 1
      t.uuid :skill1_id
      t.integer :skill1_level, default: 1
      t.uuid :skill2_id
      t.integer :skill2_level, default: 1
      t.uuid :skill3_id
      t.integer :skill3_level, default: 1
      t.uuid :skill4_id
      t.integer :skill4_level, default: 1

      t.timestamps

      t.index :party_id
      t.index [:grid_character_id], unique: true
      t.index :collection_artifact_id
      t.index :artifact_id
    end

    add_foreign_key :grid_artifacts, :parties
    add_foreign_key :grid_artifacts, :grid_characters
    add_foreign_key :grid_artifacts, :collection_artifacts
    add_foreign_key :grid_artifacts, :artifacts
    add_foreign_key :grid_artifacts, :artifact_skills, column: :skill1_id
    add_foreign_key :grid_artifacts, :artifact_skills, column: :skill2_id
    add_foreign_key :grid_artifacts, :artifact_skills, column: :skill3_id
    add_foreign_key :grid_artifacts, :artifact_skills, column: :skill4_id
  end
end
```

### Phase 2: Model Implementation

#### 2.1 Artifact Model

```ruby
# app/models/artifact.rb
class Artifact < ApplicationRecord
  # Associations
  has_many :collection_artifacts, dependent: :restrict_with_error
  has_many :grid_artifacts, dependent: :restrict_with_error

  # Validations
  validates :name_en, :name_jp, presence: true
  validates :rarity, inclusion: { in: 3..5 }
  validates :max_level, presence: true

  # Scopes
  scope :standard, -> { where(is_quirk: false) }
  scope :quirk, -> { where(is_quirk: true) }
  scope :by_rarity, ->(rarity) { where(rarity: rarity) }
  scope :by_weapon_specialty, ->(spec) { where(weapon_specialty: spec) }

  # Enums
  enum weapon_specialty: {
    sabre: 1,
    dagger: 2,
    spear: 3,
    axe: 4,
    staff: 5,
    gun: 6,
    melee: 7,
    bow: 8,
    harp: 9,
    katana: 10
  }

  enum series: {
    revans: 1,
    sephira: 2,
    arcarum: 3,
    providence: 4
  }

  # Methods
  def max_skill_slots
    is_quirk ? 4 : 3
  end
end
```

#### 2.2 Artifact Skill Model

```ruby
# app/models/artifact_skill.rb
class ArtifactSkill < ApplicationRecord
  # Constants
  GROUP_I = 1
  GROUP_II = 2
  GROUP_III = 3

  # Validations
  validates :name_en, :name_jp, presence: true
  validates :skill_group, inclusion: { in: [GROUP_I, GROUP_II, GROUP_III] }
  validates :max_level, presence: true

  # Scopes
  scope :group_i, -> { where(skill_group: GROUP_I) }
  scope :group_ii, -> { where(skill_group: GROUP_II) }
  scope :group_iii, -> { where(skill_group: GROUP_III) }

  # Methods
  def group_name
    case skill_group
    when GROUP_I then "Group I"
    when GROUP_II then "Group II"
    when GROUP_III then "Group III"
    end
  end
end
```

#### 2.3 Collection Artifact Model

```ruby
# app/models/collection_artifact.rb
class CollectionArtifact < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :artifact
  belongs_to :skill1, class_name: 'ArtifactSkill', optional: true
  belongs_to :skill2, class_name: 'ArtifactSkill', optional: true
  belongs_to :skill3, class_name: 'ArtifactSkill', optional: true
  belongs_to :skill4, class_name: 'ArtifactSkill', optional: true

  has_one :grid_artifact, dependent: :nullify

  # Validations
  validates :level, numericality: {
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: ->(ca) { ca.artifact&.max_level || 200 }
  }

  validates :skill1_level, :skill2_level, :skill3_level,
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 15 },
            allow_nil: true

  validates :skill4_level,
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 15 },
            allow_nil: true

  validate :validate_skill4_for_quirk_only
  validate :validate_skill_presence

  # Scopes
  scope :for_user, ->(user) { where(user: user) }
  scope :by_artifact, ->(artifact_id) { where(artifact_id: artifact_id) }

  # Methods
  def skills
    [skill1, skill2, skill3, skill4].compact
  end

  def skill_levels
    {
      skill1_id => skill1_level,
      skill2_id => skill2_level,
      skill3_id => skill3_level,
      skill4_id => skill4_level
    }.compact
  end

  private

  def validate_skill4_for_quirk_only
    if skill4_id.present? && artifact && !artifact.is_quirk
      errors.add(:skill4_id, "can only be set for quirk artifacts")
    end
  end

  def validate_skill_presence
    if artifact && artifact.is_quirk
      if [skill1_id, skill2_id, skill3_id, skill4_id].any?(&:blank?)
        errors.add(:base, "Quirk artifacts must have all 4 skills")
      end
    elsif artifact && !artifact.is_quirk
      if [skill1_id, skill2_id, skill3_id].any?(&:blank?)
        errors.add(:base, "Standard artifacts must have 3 skills")
      end
    end
  end
end
```

#### 2.4 Grid Artifact Model

```ruby
# app/models/grid_artifact.rb
class GridArtifact < ApplicationRecord
  # Associations
  belongs_to :party
  belongs_to :grid_character
  belongs_to :collection_artifact, optional: true
  belongs_to :artifact, optional: true
  belongs_to :skill1, class_name: 'ArtifactSkill', optional: true
  belongs_to :skill2, class_name: 'ArtifactSkill', optional: true
  belongs_to :skill3, class_name: 'ArtifactSkill', optional: true
  belongs_to :skill4, class_name: 'ArtifactSkill', optional: true

  # Validations
  validates :grid_character_id, uniqueness: true
  validate :validate_artifact_source
  validate :validate_party_ownership

  # Callbacks
  before_validation :sync_from_collection, if: :from_collection?

  # Methods
  def from_collection?
    collection_artifact_id.present?
  end

  def artifact_details
    if from_collection?
      collection_artifact.artifact
    else
      artifact
    end
  end

  def skills
    if from_collection?
      collection_artifact.skills
    else
      [skill1, skill2, skill3, skill4].compact
    end
  end

  def skill_levels
    if from_collection?
      collection_artifact.skill_levels
    else
      {
        skill1_id => skill1_level,
        skill2_id => skill2_level,
        skill3_id => skill3_level,
        skill4_id => skill4_level
      }.compact
    end
  end

  private

  def sync_from_collection
    return unless collection_artifact

    self.artifact_id = collection_artifact.artifact_id
    self.level = collection_artifact.level
    self.skill1_id = collection_artifact.skill1_id
    self.skill1_level = collection_artifact.skill1_level
    self.skill2_id = collection_artifact.skill2_id
    self.skill2_level = collection_artifact.skill2_level
    self.skill3_id = collection_artifact.skill3_id
    self.skill3_level = collection_artifact.skill3_level
    self.skill4_id = collection_artifact.skill4_id
    self.skill4_level = collection_artifact.skill4_level
  end

  def validate_artifact_source
    if collection_artifact_id.blank? && artifact_id.blank?
      errors.add(:base, "Must specify either collection artifact or quick-build artifact")
    end
  end

  def validate_party_ownership
    if grid_character && grid_character.party_id != party_id
      errors.add(:grid_character, "must belong to the same party")
    end
  end
end
```

#### 2.5 Model Updates

```ruby
# app/models/user.rb (additions)
class User < ApplicationRecord
  # ... existing code ...

  has_many :collection_artifacts, dependent: :destroy
end

# app/models/grid_character.rb (additions)
class GridCharacter < ApplicationRecord
  # ... existing code ...

  has_one :grid_artifact, dependent: :destroy

  def has_artifact?
    grid_artifact.present?
  end
end

# app/models/party.rb (additions)
class Party < ApplicationRecord
  # ... existing code ...

  has_many :grid_artifacts, dependent: :destroy
end
```

### Phase 3: API Implementation

#### 3.1 Collection Artifacts Controller

```ruby
# app/controllers/api/v1/collection/artifacts_controller.rb
module Api
  module V1
    module Collection
      class ArtifactsController < ApplicationController
        before_action :authenticate_user!
        before_action :set_collection_artifact, only: [:show, :update, :destroy]

        # GET /api/v1/collection/artifacts
        def index
          artifacts = current_user.collection_artifacts
                                  .includes(:artifact, :skill1, :skill2, :skill3, :skill4)

          artifacts = artifacts.by_artifact(params[:artifact_id]) if params[:artifact_id].present?

          render json: CollectionArtifactBlueprint.render(
            artifacts.page(params[:page]).per(params[:per_page] || 50),
            root: :collection_artifacts,
            meta: pagination_meta(artifacts)
          )
        end

        # GET /api/v1/collection/artifacts/:id
        def show
          render json: CollectionArtifactBlueprint.render(
            @collection_artifact,
            root: :collection_artifact,
            view: :extended
          )
        end

        # POST /api/v1/collection/artifacts
        def create
          @collection_artifact = current_user.collection_artifacts.build(collection_artifact_params)

          if @collection_artifact.save
            render json: CollectionArtifactBlueprint.render(
              @collection_artifact,
              root: :collection_artifact
            ), status: :created
          else
            render json: { errors: @collection_artifact.errors }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/collection/artifacts/:id
        def update
          if @collection_artifact.update(collection_artifact_params)
            render json: CollectionArtifactBlueprint.render(
              @collection_artifact,
              root: :collection_artifact
            )
          else
            render json: { errors: @collection_artifact.errors }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/collection/artifacts/:id
        def destroy
          if @collection_artifact.destroy
            head :no_content
          else
            render json: { errors: @collection_artifact.errors }, status: :unprocessable_entity
          end
        end

        # GET /api/v1/collection/statistics
        def statistics
          stats = {
            total_artifacts: current_user.collection_artifacts.count,
            breakdown_by_rarity: current_user.collection_artifacts
              .joins(:artifact)
              .group('artifacts.rarity')
              .count,
            breakdown_by_level: current_user.collection_artifacts
              .group(:level)
              .count
          }

          render json: stats
        end

        private

        def set_collection_artifact
          @collection_artifact = current_user.collection_artifacts.find(params[:id])
        end

        def collection_artifact_params
          params.require(:collection_artifact).permit(
            :artifact_id, :level,
            :skill1_id, :skill1_level,
            :skill2_id, :skill2_level,
            :skill3_id, :skill3_level,
            :skill4_id, :skill4_level
          )
        end
      end
    end
  end
end
```

#### 3.2 Grid Artifacts Controller

```ruby
# app/controllers/api/v1/grid_artifacts_controller.rb
module Api
  module V1
    class GridArtifactsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_party
      before_action :authorize_party_edit!
      before_action :set_grid_artifact, only: [:show, :update, :destroy]

      # GET /api/v1/parties/:party_id/grid_artifacts
      def index
        artifacts = @party.grid_artifacts
                          .includes(:grid_character, :artifact, :collection_artifact,
                                    :skill1, :skill2, :skill3, :skill4)

        render json: GridArtifactBlueprint.render(
          artifacts,
          root: :grid_artifacts
        )
      end

      # GET /api/v1/parties/:party_id/grid_artifacts/:id
      def show
        render json: GridArtifactBlueprint.render(
          @grid_artifact,
          root: :grid_artifact,
          view: :extended
        )
      end

      # POST /api/v1/parties/:party_id/grid_artifacts
      def create
        @grid_artifact = @party.grid_artifacts.build(grid_artifact_params)

        if @grid_artifact.save
          render json: GridArtifactBlueprint.render(
            @grid_artifact,
            root: :grid_artifact
          ), status: :created
        else
          render json: { errors: @grid_artifact.errors }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/parties/:party_id/grid_artifacts/:id
      def update
        if @grid_artifact.update(grid_artifact_params)
          render json: GridArtifactBlueprint.render(
            @grid_artifact,
            root: :grid_artifact
          )
        else
          render json: { errors: @grid_artifact.errors }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/parties/:party_id/grid_artifacts/:id
      def destroy
        if @grid_artifact.destroy
          head :no_content
        else
          render json: { errors: @grid_artifact.errors }, status: :unprocessable_entity
        end
      end

      private

      def set_party
        @party = current_user.parties.find(params[:party_id])
      end

      def set_grid_artifact
        @grid_artifact = @party.grid_artifacts.find(params[:id])
      end

      def authorize_party_edit!
        unless @party.user == current_user
          render json: { error: "Not authorized" }, status: :forbidden
        end
      end

      def grid_artifact_params
        params.require(:grid_artifact).permit(
          :grid_character_id, :collection_artifact_id, :artifact_id, :level,
          :skill1_id, :skill1_level,
          :skill2_id, :skill2_level,
          :skill3_id, :skill3_level,
          :skill4_id, :skill4_level
        )
      end
    end
  end
end
```

#### 3.3 Artifacts Controller (Canonical Data)

```ruby
# app/controllers/api/v1/artifacts_controller.rb
module Api
  module V1
    class ArtifactsController < ApplicationController
      before_action :set_artifact, only: [:show]

      # GET /api/v1/artifacts
      def index
        artifacts = Artifact.all
        artifacts = artifacts.quirk if params[:is_quirk] == 'true'
        artifacts = artifacts.standard if params[:is_quirk] == 'false'
        artifacts = artifacts.by_weapon_specialty(params[:weapon_specialty]) if params[:weapon_specialty].present?

        render json: ArtifactBlueprint.render(
          artifacts.page(params[:page]).per(params[:per_page] || 50),
          root: :artifacts,
          meta: pagination_meta(artifacts)
        )
      end

      # GET /api/v1/artifacts/:id
      def show
        render json: ArtifactBlueprint.render(
          @artifact,
          root: :artifact
        )
      end

      private

      def set_artifact
        @artifact = Artifact.find(params[:id])
      end
    end
  end
end

# app/controllers/api/v1/artifact_skills_controller.rb
module Api
  module V1
    class ArtifactSkillsController < ApplicationController
      before_action :set_artifact_skill, only: [:show]

      # GET /api/v1/artifact_skills
      def index
        skills = ArtifactSkill.all
        skills = skills.where(skill_group: params[:skill_group]) if params[:skill_group].present?

        render json: ArtifactSkillBlueprint.render(
          skills.page(params[:page]).per(params[:per_page] || 50),
          root: :artifact_skills,
          meta: pagination_meta(skills)
        )
      end

      # GET /api/v1/artifact_skills/:id
      def show
        render json: ArtifactSkillBlueprint.render(
          @artifact_skill,
          root: :artifact_skill
        )
      end

      private

      def set_artifact_skill
        @artifact_skill = ArtifactSkill.find(params[:id])
      end
    end
  end
end
```

#### 3.4 User Collections Controller

```ruby
# app/controllers/api/v1/users/collection/artifacts_controller.rb
module Api
  module V1
    module Users
      module Collection
        class ArtifactsController < ApplicationController
          before_action :set_user

          # GET /api/v1/users/:user_id/collection/artifacts
          def index
            unless can_view_collection?(@user)
              render json: { error: "You do not have permission to view this collection" },
                     status: :forbidden
              return
            end

            artifacts = @user.collection_artifacts
                             .includes(:artifact, :skill1, :skill2, :skill3, :skill4)

            render json: CollectionArtifactBlueprint.render(
              artifacts.page(params[:page]).per(params[:per_page] || 50),
              root: :collection_artifacts,
              meta: pagination_meta(artifacts)
            )
          end

          private

          def set_user
            @user = User.find(params[:user_id])
          end

          def can_view_collection?(user)
            case user.collection_privacy
            when 'public'
              true
            when 'crew_only'
              # Check if viewer is in same crew (when crew feature is implemented)
              current_user && current_user.crew_id == user.crew_id
            when 'private'
              current_user && current_user.id == user.id
            else
              false
            end
          end
        end
      end
    end
  end
end
```

### Phase 4: Blueprints

```ruby
# app/blueprints/artifact_blueprint.rb
class ArtifactBlueprint < ApplicationBlueprint
  identifier :id

  fields :name_en, :name_jp, :series, :weapon_specialty, :rarity, :is_quirk, :max_level

  field :max_skill_slots do |artifact|
    artifact.max_skill_slots
  end
end

# app/blueprints/artifact_skill_blueprint.rb
class ArtifactSkillBlueprint < ApplicationBlueprint
  identifier :id

  fields :name_en, :name_jp, :skill_group, :effect_type, :max_level,
         :description_en, :description_jp

  field :group_name do |skill|
    skill.group_name
  end
end

# app/blueprints/collection_artifact_blueprint.rb
class CollectionArtifactBlueprint < ApplicationBlueprint
  identifier :id

  fields :level, :created_at, :updated_at

  association :artifact, blueprint: ArtifactBlueprint

  field :skills do |ca|
    skills = []

    if ca.skill1
      skills << {
        slot: 1,
        skill: ArtifactSkillBlueprint.render_as_hash(ca.skill1),
        level: ca.skill1_level
      }
    end

    if ca.skill2
      skills << {
        slot: 2,
        skill: ArtifactSkillBlueprint.render_as_hash(ca.skill2),
        level: ca.skill2_level
      }
    end

    if ca.skill3
      skills << {
        slot: 3,
        skill: ArtifactSkillBlueprint.render_as_hash(ca.skill3),
        level: ca.skill3_level
      }
    end

    if ca.skill4
      skills << {
        slot: 4,
        skill: ArtifactSkillBlueprint.render_as_hash(ca.skill4),
        level: ca.skill4_level
      }
    end

    skills
  end

  view :extended do
    field :equipped_in_parties do |ca|
      ca.grid_artifact&.party_id
    end
  end
end

# app/blueprints/grid_artifact_blueprint.rb
class GridArtifactBlueprint < ApplicationBlueprint
  identifier :id

  field :from_collection do |ga|
    ga.from_collection?
  end

  field :level do |ga|
    ga.from_collection? ? ga.collection_artifact.level : ga.level
  end

  association :grid_character, blueprint: GridCharacterBlueprint

  field :artifact do |ga|
    ArtifactBlueprint.render_as_hash(ga.artifact_details)
  end

  field :skills do |ga|
    skills = []
    skill_levels = ga.skill_levels

    ga.skills.each_with_index do |skill, index|
      next unless skill
      skills << {
        slot: index + 1,
        skill: ArtifactSkillBlueprint.render_as_hash(skill),
        level: skill_levels[skill.id] || 1
      }
    end

    skills
  end

  view :extended do
    association :collection_artifact, blueprint: CollectionArtifactBlueprint,
                if: ->(ga) { ga.from_collection? }
  end
end
```

### Phase 5: Routes Configuration

```ruby
# config/routes.rb (additions)
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Canonical artifact data
      resources :artifacts, only: [:index, :show]
      resources :artifact_skills, only: [:index, :show]

      # User collection
      namespace :collection do
        resources :artifacts do
          collection do
            get 'statistics'
          end
        end
      end

      # Grid artifacts (nested under parties)
      resources :parties do
        resources :grid_artifacts
      end

      # View other users' collections
      resources :users, only: [] do
        namespace :collection do
          resources :artifacts, only: [:index]
        end
      end
    end
  end
end
```

### Phase 6: Seed Data

```ruby
# db/seeds/artifacts.rb

# Create artifact skills
puts "Creating artifact skills..."

# Group I Skills
group_i_skills = [
  { name_en: "ATK Up", name_jp: "攻撃力アップ", skill_group: 1, effect_type: "atk", max_level: 15 },
  { name_en: "HP Up", name_jp: "HPアップ", skill_group: 1, effect_type: "hp", max_level: 15 },
  { name_en: "Critical Hit Rate", name_jp: "クリティカル確率", skill_group: 1, effect_type: "crit", max_level: 15 },
  { name_en: "Double Attack Rate", name_jp: "連続攻撃確率", skill_group: 1, effect_type: "da", max_level: 15 },
  { name_en: "Triple Attack Rate", name_jp: "トリプルアタック確率", skill_group: 1, effect_type: "ta", max_level: 15 }
]

# Group II Skills
group_ii_skills = [
  { name_en: "Enmity", name_jp: "背水", skill_group: 2, effect_type: "enmity", max_level: 10 },
  { name_en: "Stamina", name_jp: "渾身", skill_group: 2, effect_type: "stamina", max_level: 10 },
  { name_en: "Charge Bar Gain", name_jp: "奥義ゲージ上昇量", skill_group: 2, effect_type: "charge", max_level: 10 }
]

# Group III Skills
group_iii_skills = [
  { name_en: "Skill DMG Cap Up", name_jp: "アビリティダメージ上限", skill_group: 3, effect_type: "skill_cap", max_level: 5 },
  { name_en: "C.A. DMG Cap Up", name_jp: "奥義ダメージ上限", skill_group: 3, effect_type: "ca_cap", max_level: 5 },
  { name_en: "Normal Attack Cap Up", name_jp: "通常攻撃上限", skill_group: 3, effect_type: "auto_cap", max_level: 5 }
]

(group_i_skills + group_ii_skills + group_iii_skills).each do |skill_data|
  ArtifactSkill.find_or_create_by!(
    name_en: skill_data[:name_en]
  ) do |skill|
    skill.assign_attributes(skill_data)
  end
end

# Create artifacts
puts "Creating artifacts..."

standard_artifacts = [
  { name_en: "Revans Gauntlet", name_jp: "レヴァンスガントレット", series: 1, weapon_specialty: 7, rarity: 5, is_quirk: false, max_level: 150 },
  { name_en: "Revans Armor", name_jp: "レヴァンスアーマー", series: 1, weapon_specialty: 1, rarity: 5, is_quirk: false, max_level: 150 },
  { name_en: "Sephira Ring", name_jp: "セフィラリング", series: 2, weapon_specialty: 5, rarity: 5, is_quirk: false, max_level: 150 },
  { name_en: "Arcarum Card", name_jp: "アーカルムカード", series: 3, weapon_specialty: 2, rarity: 4, is_quirk: false, max_level: 150 }
]

quirk_artifacts = [
  { name_en: "Quirk: Crimson Finger", name_jp: "絆器：クリムゾンフィンガー", series: 4, weapon_specialty: 6, rarity: 5, is_quirk: true, max_level: 200 },
  { name_en: "Quirk: Blue Sphere", name_jp: "絆器：ブルースフィア", series: 4, weapon_specialty: 5, rarity: 5, is_quirk: true, max_level: 200 }
]

(standard_artifacts + quirk_artifacts).each do |artifact_data|
  Artifact.find_or_create_by!(
    name_en: artifact_data[:name_en]
  ) do |artifact|
    artifact.assign_attributes(artifact_data)
  end
end

puts "Seeded #{ArtifactSkill.count} artifact skills and #{Artifact.count} artifacts"
```

### Phase 7: Testing

#### 7.1 Model Specs

```ruby
# spec/models/artifact_spec.rb
require 'rails_helper'

RSpec.describe Artifact, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name_en) }
    it { should validate_presence_of(:name_jp) }
    it { should validate_inclusion_of(:rarity).in_array([3, 4, 5]) }
  end

  describe 'associations' do
    it { should have_many(:collection_artifacts) }
    it { should have_many(:grid_artifacts) }
  end

  describe '#max_skill_slots' do
    it 'returns 3 for standard artifacts' do
      artifact = build(:artifact, is_quirk: false)
      expect(artifact.max_skill_slots).to eq(3)
    end

    it 'returns 4 for quirk artifacts' do
      artifact = build(:artifact, is_quirk: true)
      expect(artifact.max_skill_slots).to eq(4)
    end
  end
end

# spec/models/collection_artifact_spec.rb
require 'rails_helper'

RSpec.describe CollectionArtifact, type: :model do
  let(:user) { create(:user) }
  let(:standard_artifact) { create(:artifact, is_quirk: false) }
  let(:quirk_artifact) { create(:artifact, is_quirk: true) }

  describe 'validations' do
    it 'validates level is within artifact max level' do
      ca = build(:collection_artifact, artifact: standard_artifact, level: 151)
      expect(ca).not_to be_valid
      expect(ca.errors[:level]).to be_present
    end

    it 'prevents skill4 on standard artifacts' do
      ca = build(:collection_artifact,
        artifact: standard_artifact,
        skill4: create(:artifact_skill)
      )
      expect(ca).not_to be_valid
      expect(ca.errors[:skill4_id]).to include("can only be set for quirk artifacts")
    end

    it 'allows skill4 on quirk artifacts' do
      ca = build(:collection_artifact,
        artifact: quirk_artifact,
        skill1: create(:artifact_skill, skill_group: 1),
        skill2: create(:artifact_skill, skill_group: 1),
        skill3: create(:artifact_skill, skill_group: 2),
        skill4: create(:artifact_skill, skill_group: 3)
      )
      expect(ca).to be_valid
    end
  end
end

# spec/models/grid_artifact_spec.rb
require 'rails_helper'

RSpec.describe GridArtifact, type: :model do
  let(:party) { create(:party) }
  let(:grid_character) { create(:grid_character, party: party) }
  let(:collection_artifact) { create(:collection_artifact) }

  describe 'validations' do
    it 'ensures one artifact per character' do
      create(:grid_artifact, party: party, grid_character: grid_character)
      duplicate = build(:grid_artifact, party: party, grid_character: grid_character)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:grid_character_id]).to be_present
    end

    it 'requires either collection or quick-build artifact' do
      ga = build(:grid_artifact, party: party, grid_character: grid_character)
      expect(ga).not_to be_valid
      expect(ga.errors[:base]).to include("Must specify either collection artifact or quick-build artifact")
    end
  end

  describe '#from_collection?' do
    it 'returns true when using collection artifact' do
      ga = build(:grid_artifact, collection_artifact: collection_artifact)
      expect(ga.from_collection?).to be true
    end

    it 'returns false when quick-building' do
      ga = build(:grid_artifact, artifact: create(:artifact))
      expect(ga.from_collection?).to be false
    end
  end
end
```

#### 7.2 Controller Specs

```ruby
# spec/controllers/api/v1/collection/artifacts_controller_spec.rb
require 'rails_helper'

RSpec.describe Api::V1::Collection::ArtifactsController, type: :controller do
  let(:user) { create(:user) }
  let(:artifact) { create(:artifact) }
  let(:skill1) { create(:artifact_skill, skill_group: 1) }
  let(:skill2) { create(:artifact_skill, skill_group: 1) }
  let(:skill3) { create(:artifact_skill, skill_group: 2) }

  before { sign_in user }

  describe 'GET #index' do
    let!(:collection_artifacts) { create_list(:collection_artifact, 3, user: user) }

    it 'returns user collection artifacts' do
      get :index
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['collection_artifacts'].size).to eq(3)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        collection_artifact: {
          artifact_id: artifact.id,
          level: 50,
          skill1_id: skill1.id,
          skill1_level: 5,
          skill2_id: skill2.id,
          skill2_level: 3,
          skill3_id: skill3.id,
          skill3_level: 2
        }
      }
    end

    it 'creates a new collection artifact' do
      expect {
        post :create, params: valid_params
      }.to change(CollectionArtifact, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe 'DELETE #destroy' do
    let!(:collection_artifact) { create(:collection_artifact, user: user) }

    it 'deletes the artifact' do
      expect {
        delete :destroy, params: { id: collection_artifact.id }
      }.to change(CollectionArtifact, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
```

## Deployment Checklist

### Pre-deployment
- [ ] Run all migrations in development
- [ ] Seed artifact and skill data
- [ ] Test all CRUD operations
- [ ] Verify privacy controls work correctly

### Deployment
1. Deploy database migrations
2. Run seed data for artifacts and skills
3. Deploy application code
4. Verify artifact endpoints
5. Test collection and grid functionality

### Post-deployment
- [ ] Monitor error rates
- [ ] Check database performance
- [ ] Verify user collections are accessible
- [ ] Test party integration

## Performance Considerations

1. **Database Indexes**: All foreign keys and common query patterns are indexed
2. **Eager Loading**: Use includes() to prevent N+1 queries
3. **Pagination**: All list endpoints support pagination

## Security Notes

1. **Authorization**: Users can only modify their own collection
2. **Privacy**: Collection viewing respects user privacy settings
3. **Validation**: Strict validation at model level
4. **Party Ownership**: Only party owners can modify grid artifacts