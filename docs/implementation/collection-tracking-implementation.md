# Collection Tracking Implementation Guide

## Prerequisites

- Rails 8.0.1 environment set up
- PostgreSQL database running
- Basic understanding of the existing codebase structure
- Familiarity with Rails migrations, models, and controllers

## Step-by-Step Implementation

### Step 1: Create Database Migrations

#### 1.0 Add collection privacy levels to Users table

```bash
rails generate migration AddCollectionPrivacyToUsers
```

```ruby
# db/migrate/xxx_add_collection_privacy_to_users.rb
class AddCollectionPrivacyToUsers < ActiveRecord::Migration[8.0]
  def change
    # Privacy levels: 0 = public, 1 = crew_only, 2 = private
    add_column :users, :collection_privacy, :integer, default: 0, null: false
    add_index :users, :collection_privacy
  end
end
```

#### 1.1 Create CollectionCharacters migration

```bash
rails generate migration CreateCollectionCharacters
```

```ruby
# db/migrate/xxx_create_collection_characters.rb
class CreateCollectionCharacters < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_characters, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :character, type: :uuid, null: false, foreign_key: true
      t.integer :uncap_level, default: 0, null: false
      t.integer :transcendence_step, default: 0, null: false
      t.boolean :perpetuity, default: false, null: false
      t.references :awakening, type: :uuid, foreign_key: true
      t.integer :awakening_level, default: 1

      t.jsonb :ring1, default: { modifier: nil, strength: nil }, null: false
      t.jsonb :ring2, default: { modifier: nil, strength: nil }, null: false
      t.jsonb :ring3, default: { modifier: nil, strength: nil }, null: false
      t.jsonb :ring4, default: { modifier: nil, strength: nil }, null: false
      t.jsonb :earring, default: { modifier: nil, strength: nil }, null: false

      t.timestamps
    end

    add_index :collection_characters, [:user_id, :character_id], unique: true
    add_index :collection_characters, :user_id
    add_index :collection_characters, :character_id
  end
end
```

#### 1.2 Create CollectionWeapons migration

```bash
rails generate migration CreateCollectionWeapons
```

```ruby
# db/migrate/xxx_create_collection_weapons.rb
class CreateCollectionWeapons < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_weapons, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :weapon, type: :uuid, null: false, foreign_key: true
      t.integer :uncap_level, default: 0, null: false
      t.integer :transcendence_step, default: 0

      t.references :weapon_key1, type: :uuid, foreign_key: { to_table: :weapon_keys }
      t.references :weapon_key2, type: :uuid, foreign_key: { to_table: :weapon_keys }
      t.references :weapon_key3, type: :uuid, foreign_key: { to_table: :weapon_keys }
      t.string :weapon_key4_id

      t.references :awakening, type: :uuid, foreign_key: true
      t.integer :awakening_level, default: 1, null: false

      t.integer :ax_modifier1
      t.float :ax_strength1
      t.integer :ax_modifier2
      t.float :ax_strength2
      t.integer :element

      t.timestamps
    end

    add_index :collection_weapons, :user_id
    add_index :collection_weapons, :weapon_id
    add_index :collection_weapons, [:user_id, :weapon_id]
  end
end
```

#### 1.3 Create CollectionSummons migration

```bash
rails generate migration CreateCollectionSummons
```

```ruby
# db/migrate/xxx_create_collection_summons.rb
class CreateCollectionSummons < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_summons, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :summon, type: :uuid, null: false, foreign_key: true
      t.integer :uncap_level, default: 0, null: false
      t.integer :transcendence_step, default: 0, null: false

      t.timestamps
    end

    add_index :collection_summons, :user_id
    add_index :collection_summons, :summon_id
    add_index :collection_summons, [:user_id, :summon_id]
  end
end
```

#### 1.4 Create CollectionJobAccessories migration

```bash
rails generate migration CreateCollectionJobAccessories
```

```ruby
# db/migrate/xxx_create_collection_job_accessories.rb
class CreateCollectionJobAccessories < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_job_accessories, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :job_accessory, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end

    add_index :collection_job_accessories, [:user_id, :job_accessory_id],
              unique: true, name: 'idx_collection_job_acc_user_accessory'
    add_index :collection_job_accessories, :user_id
    add_index :collection_job_accessories, :job_accessory_id
  end
end
```

#### 1.5 Run migrations

```bash
rails db:migrate
```

### Step 2: Create Models

#### 2.1 Create CollectionCharacter model

```ruby
# app/models/collection_character.rb
class CollectionCharacter < ApplicationRecord
  belongs_to :user
  belongs_to :character
  belongs_to :awakening, optional: true

  validates :character_id, uniqueness: { scope: :user_id,
    message: "already exists in your collection" }
  validates :uncap_level, inclusion: { in: 0..5 }
  validates :transcendence_step, inclusion: { in: 0..10 }
  validates :awakening_level, inclusion: { in: 1..10 }

  validate :validate_rings
  validate :validate_awakening_compatibility

  scope :by_element, ->(element) { joins(:character).where(characters: { element: element }) }
  scope :by_rarity, ->(rarity) { joins(:character).where(characters: { rarity: rarity }) }
  scope :transcended, -> { where('transcendence_step > 0') }
  scope :with_awakening, -> { where.not(awakening_id: nil) }

  def blueprint
    CollectionCharacterBlueprint
  end

  private

  def validate_rings
    [ring1, ring2, ring3, ring4, earring].each_with_index do |ring, index|
      next unless ring['modifier'].present? || ring['strength'].present?

      if ring['modifier'].blank? || ring['strength'].blank?
        errors.add(:base, "Ring #{index + 1} must have both modifier and strength")
      end
    end
  end

  def validate_awakening_compatibility
    return unless awakening.present?

    unless awakening.object_type == 'Character'
      errors.add(:awakening, "must be a character awakening")
    end
  end
end
```

#### 2.2 Create CollectionWeapon model

```ruby
# app/models/collection_weapon.rb
class CollectionWeapon < ApplicationRecord
  belongs_to :user
  belongs_to :weapon
  belongs_to :awakening, optional: true

  belongs_to :weapon_key1, class_name: 'WeaponKey', optional: true
  belongs_to :weapon_key2, class_name: 'WeaponKey', optional: true
  belongs_to :weapon_key3, class_name: 'WeaponKey', optional: true
  belongs_to :weapon_key4, class_name: 'WeaponKey', optional: true

  validates :uncap_level, inclusion: { in: 0..5 }
  validates :transcendence_step, inclusion: { in: 0..10 }, allow_nil: true
  validates :awakening_level, inclusion: { in: 1..10 }

  validate :validate_weapon_keys
  validate :validate_ax_skills
  validate :validate_element_change
  validate :validate_awakening_compatibility

  scope :by_weapon, ->(weapon_id) { where(weapon_id: weapon_id) }
  scope :by_series, ->(series) { joins(:weapon).where(weapons: { series: series }) }
  scope :with_keys, -> { where.not(weapon_key1_id: nil) }
  scope :with_ax, -> { where.not(ax_modifier1: nil) }

  def blueprint
    CollectionWeaponBlueprint
  end

  def weapon_keys
    [weapon_key1, weapon_key2, weapon_key3, weapon_key4].compact
  end

  private

  def validate_weapon_keys
    return unless weapon.present?

    weapon_keys.each do |key|
      unless weapon.compatible_with_key?(key)
        errors.add(:weapon_keys, "#{key.name_en} is not compatible with this weapon")
      end
    end

    # Check for duplicate keys
    key_ids = [weapon_key1_id, weapon_key2_id, weapon_key3_id, weapon_key4_id].compact
    if key_ids.length != key_ids.uniq.length
      errors.add(:weapon_keys, "cannot have duplicate keys")
    end
  end

  def validate_ax_skills
    return unless weapon.present? && weapon.ax

    if (ax_modifier1.present? && ax_strength1.blank?) ||
       (ax_modifier1.blank? && ax_strength1.present?)
      errors.add(:ax_modifier1, "AX skill 1 must have both modifier and strength")
    end

    if (ax_modifier2.present? && ax_strength2.blank?) ||
       (ax_modifier2.blank? && ax_strength2.present?)
      errors.add(:ax_modifier2, "AX skill 2 must have both modifier and strength")
    end
  end

  def validate_element_change
    return unless element.present? && weapon.present?

    unless Weapon.element_changeable?(weapon.series)
      errors.add(:element, "cannot be changed for this weapon series")
    end
  end

  def validate_awakening_compatibility
    return unless awakening.present?

    unless awakening.object_type == 'Weapon'
      errors.add(:awakening, "must be a weapon awakening")
    end
  end
end
```

#### 2.3 Create CollectionSummon model

```ruby
# app/models/collection_summon.rb
class CollectionSummon < ApplicationRecord
  belongs_to :user
  belongs_to :summon

  validates :uncap_level, inclusion: { in: 0..5 }
  validates :transcendence_step, inclusion: { in: 0..10 }

  scope :by_summon, ->(summon_id) { where(summon_id: summon_id) }
  scope :by_element, ->(element) { joins(:summon).where(summons: { element: element }) }
  scope :transcended, -> { where('transcendence_step > 0') }

  def blueprint
    CollectionSummonBlueprint
  end
end
```

#### 2.4 Create CollectionJobAccessory model

```ruby
# app/models/collection_job_accessory.rb
class CollectionJobAccessory < ApplicationRecord
  belongs_to :user
  belongs_to :job_accessory

  validates :job_accessory_id, uniqueness: { scope: :user_id,
    message: "already exists in your collection" }

  scope :by_job, ->(job_id) { joins(:job_accessory).where(job_accessories: { job_id: job_id }) }

  def blueprint
    CollectionJobAccessoryBlueprint
  end
end
```

#### 2.5 Update User model

```ruby
# app/models/user.rb - Add these associations and methods

# Associations
has_many :collection_characters, dependent: :destroy
has_many :collection_weapons, dependent: :destroy
has_many :collection_summons, dependent: :destroy
has_many :collection_job_accessories, dependent: :destroy

# Note: The crew association will be added when crews feature is implemented
# belongs_to :crew, optional: true

# Enum for collection privacy levels
enum collection_privacy: {
  public: 0,
  crew_only: 1,
  private: 2
}

# Add collection statistics method
def collection_statistics
  {
    total_characters: collection_characters.count,
    total_weapons: collection_weapons.count,
    total_summons: collection_summons.count,
    total_job_accessories: collection_job_accessories.count,
    unique_weapons: collection_weapons.distinct.count(:weapon_id),
    unique_summons: collection_summons.distinct.count(:summon_id)
  }
end

# Check if collection is viewable by another user
def collection_viewable_by?(viewer)
  return true if self == viewer # Owners can always view their own collection

  case collection_privacy
  when 'public'
    true
  when 'crew_only'
    # Will be implemented when crew feature is added:
    # viewer.present? && crew.present? && viewer.crew_id == crew_id
    false # For now, crew_only acts like private until crews are implemented
  when 'private'
    false
  else
    false
  end
end

# Helper method to check if user is in same crew (placeholder for future)
def in_same_crew_as?(other_user)
  # Will be implemented when crew feature is added:
  # return false unless other_user.present?
  # crew.present? && other_user.crew_id == crew_id
  false
end
```

### Step 3: Create Blueprints

#### 3.1 CollectionCharacterBlueprint

```ruby
# app/blueprints/api/v1/collection_character_blueprint.rb
module Api
  module V1
    class CollectionCharacterBlueprint < ApiBlueprint
      identifier :id

      fields :uncap_level, :transcendence_step, :perpetuity,
             :ring1, :ring2, :ring3, :ring4, :earring,
             :created_at, :updated_at

      field :awakening, if: ->(_, obj, _) { obj.awakening.present? } do |obj|
        {
          type: AwakeningBlueprint.render_as_hash(obj.awakening),
          level: obj.awakening_level
        }
      end

      association :character, blueprint: CharacterBlueprint, view: :nested

      view :full do
        association :character, blueprint: CharacterBlueprint, view: :full
      end
    end
  end
end
```

#### 3.2 CollectionWeaponBlueprint

```ruby
# app/blueprints/api/v1/collection_weapon_blueprint.rb
module Api
  module V1
    class CollectionWeaponBlueprint < ApiBlueprint
      identifier :id

      fields :uncap_level, :transcendence_step, :element,
             :created_at, :updated_at

      field :ax, if: ->(_, obj, _) { obj.ax_modifier1.present? } do |obj|
        [
          { modifier: obj.ax_modifier1, strength: obj.ax_strength1 },
          { modifier: obj.ax_modifier2, strength: obj.ax_strength2 }
        ].compact_blank
      end

      field :awakening, if: ->(_, obj, _) { obj.awakening.present? } do |obj|
        {
          type: AwakeningBlueprint.render_as_hash(obj.awakening),
          level: obj.awakening_level
        }
      end

      association :weapon, blueprint: WeaponBlueprint, view: :nested
      association :weapon_keys, blueprint: WeaponKeyBlueprint,
                  if: ->(_, obj, _) { obj.weapon_keys.any? }

      view :full do
        association :weapon, blueprint: WeaponBlueprint, view: :full
      end
    end
  end
end
```

#### 3.3 CollectionSummonBlueprint

```ruby
# app/blueprints/api/v1/collection_summon_blueprint.rb
module Api
  module V1
    class CollectionSummonBlueprint < ApiBlueprint
      identifier :id

      fields :uncap_level, :transcendence_step,
             :created_at, :updated_at

      association :summon, blueprint: SummonBlueprint, view: :nested

      view :full do
        association :summon, blueprint: SummonBlueprint, view: :full
      end
    end
  end
end
```

#### 3.4 CollectionJobAccessoryBlueprint

```ruby
# app/blueprints/api/v1/collection_job_accessory_blueprint.rb
module Api
  module V1
    class CollectionJobAccessoryBlueprint < ApiBlueprint
      identifier :id

      fields :created_at, :updated_at

      association :job_accessory, blueprint: JobAccessoryBlueprint
    end
  end
end
```

### Step 4: Create Controllers

#### 4.1 Base Collection Controller (with User Collection Viewing and Privacy)

```ruby
# app/controllers/api/v1/collection_controller.rb
module Api
  module V1
    class CollectionController < ApiController
      before_action :set_user
      before_action :check_collection_access

      # GET /api/v1/users/:user_id/collection
      # GET /api/v1/users/:user_id/collection?type=weapons
      def show
        collection = case params[:type]
        when 'characters'
          {
            characters: CollectionCharacterBlueprint.render_as_hash(
              @user.collection_characters.includes(:character, :awakening),
              view: :full
            )
          }
        when 'weapons'
          {
            weapons: CollectionWeaponBlueprint.render_as_hash(
              @user.collection_weapons.includes(:weapon, :awakening, :weapon_key1,
                                               :weapon_key2, :weapon_key3, :weapon_key4),
              view: :full
            )
          }
        when 'summons'
          {
            summons: CollectionSummonBlueprint.render_as_hash(
              @user.collection_summons.includes(:summon),
              view: :full
            )
          }
        when 'job_accessories'
          {
            job_accessories: CollectionJobAccessoryBlueprint.render_as_hash(
              @user.collection_job_accessories.includes(job_accessory: :job)
            )
          }
        else
          # Return complete collection
          {
            characters: CollectionCharacterBlueprint.render_as_hash(
              @user.collection_characters.includes(:character, :awakening),
              view: :full
            ),
            weapons: CollectionWeaponBlueprint.render_as_hash(
              @user.collection_weapons.includes(:weapon, :awakening, :weapon_key1,
                                               :weapon_key2, :weapon_key3, :weapon_key4),
              view: :full
            ),
            summons: CollectionSummonBlueprint.render_as_hash(
              @user.collection_summons.includes(:summon),
              view: :full
            ),
            job_accessories: CollectionJobAccessoryBlueprint.render_as_hash(
              @user.collection_job_accessories.includes(job_accessory: :job)
            )
          }
        end

        render json: collection
      end

      def statistics
        stats = @user.collection_statistics
        render json: stats
      end

      private

      def set_user
        @user = User.find(params[:user_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      end

      def check_collection_access
        unless @user.collection_viewable_by?(current_user)
          render json: { error: "You do not have permission to view this collection" }, status: :forbidden
        end
      end
    end
  end
end
```

#### 4.2 CollectionCharactersController

```ruby
# app/controllers/api/v1/collection_characters_controller.rb
module Api
  module V1
    class CollectionCharactersController < ApiController
      before_action :authenticate_user!
      before_action :set_collection_character, only: [:show, :update, :destroy]

      def index
        @collection_characters = current_user.collection_characters
                                             .includes(:character, :awakening)
                                             .page(params[:page])
                                             .per(params[:limit] || 50)

        render json: CollectionCharacterBlueprint.render(
          @collection_characters,
          root: :collection_characters,
          meta: pagination_meta(@collection_characters)
        )
      end

      def show
        render json: CollectionCharacterBlueprint.render(
          @collection_character,
          view: :full
        )
      end

      def create
        @collection_character = current_user.collection_characters.build(collection_character_params)

        if @collection_character.save
          render json: CollectionCharacterBlueprint.render(
            @collection_character,
            view: :full
          ), status: :created
        else
          render_errors(@collection_character.errors)
        end
      end

      def update
        if @collection_character.update(collection_character_params)
          render json: CollectionCharacterBlueprint.render(
            @collection_character,
            view: :full
          )
        else
          render_errors(@collection_character.errors)
        end
      end

      def destroy
        @collection_character.destroy
        head :no_content
      end

      private

      def set_collection_character
        @collection_character = current_user.collection_characters.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Collection character not found" }, status: :not_found
      end

      def collection_character_params
        params.require(:collection_character).permit(
          :character_id, :uncap_level, :transcendence_step, :perpetuity,
          :awakening_id, :awakening_level,
          ring1: [:modifier, :strength],
          ring2: [:modifier, :strength],
          ring3: [:modifier, :strength],
          ring4: [:modifier, :strength],
          earring: [:modifier, :strength]
        )
      end
    end
  end
end
```

#### 4.3 CollectionWeaponsController

```ruby
# app/controllers/api/v1/collection_weapons_controller.rb
module Api
  module V1
    class CollectionWeaponsController < ApiController
      before_action :authenticate_user!
      before_action :set_collection_weapon, only: [:show, :update, :destroy]

      def index
        @collection_weapons = current_user.collection_weapons
                                          .includes(:weapon, :awakening,
                                                   :weapon_key1, :weapon_key2,
                                                   :weapon_key3, :weapon_key4)

        @collection_weapons = @collection_weapons.by_weapon(params[:weapon_id]) if params[:weapon_id]

        @collection_weapons = @collection_weapons.page(params[:page]).per(params[:limit] || 50)

        render json: CollectionWeaponBlueprint.render(
          @collection_weapons,
          root: :collection_weapons,
          meta: pagination_meta(@collection_weapons)
        )
      end

      def show
        render json: CollectionWeaponBlueprint.render(
          @collection_weapon,
          view: :full
        )
      end

      def create
        @collection_weapon = current_user.collection_weapons.build(collection_weapon_params)

        if @collection_weapon.save
          render json: CollectionWeaponBlueprint.render(
            @collection_weapon,
            view: :full
          ), status: :created
        else
          render_errors(@collection_weapon.errors)
        end
      end

      def update
        if @collection_weapon.update(collection_weapon_params)
          render json: CollectionWeaponBlueprint.render(
            @collection_weapon,
            view: :full
          )
        else
          render_errors(@collection_weapon.errors)
        end
      end

      def destroy
        @collection_weapon.destroy
        head :no_content
      end

      private

      def set_collection_weapon
        @collection_weapon = current_user.collection_weapons.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Collection weapon not found" }, status: :not_found
      end

      def collection_weapon_params
        params.require(:collection_weapon).permit(
          :weapon_id, :uncap_level, :transcendence_step,
          :weapon_key1_id, :weapon_key2_id, :weapon_key3_id, :weapon_key4_id,
          :awakening_id, :awakening_level,
          :ax_modifier1, :ax_strength1, :ax_modifier2, :ax_strength2,
          :element
        )
      end
    end
  end
end
```

#### 4.4 CollectionSummonsController

```ruby
# app/controllers/api/v1/collection_summons_controller.rb
module Api
  module V1
    class CollectionSummonsController < ApiController
      before_action :authenticate_user!
      before_action :set_collection_summon, only: [:show, :update, :destroy]

      def index
        @collection_summons = current_user.collection_summons
                                          .includes(:summon)

        @collection_summons = @collection_summons.by_summon(params[:summon_id]) if params[:summon_id]

        @collection_summons = @collection_summons.page(params[:page]).per(params[:limit] || 50)

        render json: CollectionSummonBlueprint.render(
          @collection_summons,
          root: :collection_summons,
          meta: pagination_meta(@collection_summons)
        )
      end

      def show
        render json: CollectionSummonBlueprint.render(
          @collection_summon,
          view: :full
        )
      end

      def create
        @collection_summon = current_user.collection_summons.build(collection_summon_params)

        if @collection_summon.save
          render json: CollectionSummonBlueprint.render(
            @collection_summon,
            view: :full
          ), status: :created
        else
          render_errors(@collection_summon.errors)
        end
      end

      def update
        if @collection_summon.update(collection_summon_params)
          render json: CollectionSummonBlueprint.render(
            @collection_summon,
            view: :full
          )
        else
          render_errors(@collection_summon.errors)
        end
      end

      def destroy
        @collection_summon.destroy
        head :no_content
      end

      private

      def set_collection_summon
        @collection_summon = current_user.collection_summons.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Collection summon not found" }, status: :not_found
      end

      def collection_summon_params
        params.require(:collection_summon).permit(
          :summon_id, :uncap_level, :transcendence_step
        )
      end
    end
  end
end
```

#### 4.5 CollectionJobAccessoriesController

```ruby
# app/controllers/api/v1/collection_job_accessories_controller.rb
module Api
  module V1
    class CollectionJobAccessoriesController < ApiController
      before_action :authenticate_user!
      before_action :set_collection_job_accessory, only: [:destroy]

      def index
        @collection_accessories = current_user.collection_job_accessories
                                              .includes(job_accessory: :job)

        if params[:job_id]
          @collection_accessories = @collection_accessories.by_job(params[:job_id])
        end

        @collection_accessories = @collection_accessories.page(params[:page])
                                                         .per(params[:limit] || 50)

        render json: CollectionJobAccessoryBlueprint.render(
          @collection_accessories,
          root: :collection_job_accessories,
          meta: pagination_meta(@collection_accessories)
        )
      end

      def create
        @collection_accessory = current_user.collection_job_accessories
                                           .build(collection_job_accessory_params)

        if @collection_accessory.save
          render json: CollectionJobAccessoryBlueprint.render(
            @collection_accessory
          ), status: :created
        else
          render_errors(@collection_accessory.errors)
        end
      end

      def destroy
        @collection_job_accessory.destroy
        head :no_content
      end

      private

      def set_collection_job_accessory
        @collection_job_accessory = current_user.collection_job_accessories.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Collection job accessory not found" }, status: :not_found
      end

      def collection_job_accessory_params
        params.require(:collection_job_accessory).permit(:job_accessory_id)
      end
    end
  end
end
```

### Step 5: Update Routes

```ruby
# config/routes.rb - Add these routes within the API scope

# User collection viewing (respects privacy settings)
get 'users/:user_id/collection', to: 'collection#show'
get 'users/:user_id/collection/statistics', to: 'collection#statistics'

# Collection management for current user
namespace :collection do
  resources :characters, controller: '/api/v1/collection_characters'
  resources :weapons, controller: '/api/v1/collection_weapons'
  resources :summons, controller: '/api/v1/collection_summons'
  resources :job_accessories, controller: '/api/v1/collection_job_accessories',
            only: [:index, :create, :destroy]
end
```

### Step 6: Add Helper Methods to ApiController

```ruby
# app/controllers/api/v1/api_controller.rb - Add these helper methods

protected

def pagination_meta(collection)
  {
    current_page: collection.current_page,
    total_pages: collection.total_pages,
    total_count: collection.total_count,
    per_page: collection.limit_value
  }
end

def render_errors(errors, status = :unprocessable_entity)
  render json: { errors: errors.full_messages }, status: status
end
```

## Testing the Implementation

### Manual Testing Steps

1. **Start Rails server**
   ```bash
   rails server
   ```

2. **View a user's complete collection**
   ```bash
   # Get complete collection
   curl -X GET http://localhost:3000/api/v1/users/USER_ID/collection

   # Get only weapons
   curl -X GET http://localhost:3000/api/v1/users/USER_ID/collection?type=weapons

   # Get only characters
   curl -X GET http://localhost:3000/api/v1/users/USER_ID/collection?type=characters

   # Get only summons
   curl -X GET http://localhost:3000/api/v1/users/USER_ID/collection?type=summons

   # Get only job accessories
   curl -X GET http://localhost:3000/api/v1/users/USER_ID/collection?type=job_accessories
   ```

3. **Get collection statistics**
   ```bash
   curl -X GET http://localhost:3000/api/v1/users/USER_ID/collection/statistics
   ```

4. **Create collection items (authenticated)**
   ```bash
   # Create a character
   curl -X POST http://localhost:3000/api/v1/collection/characters \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"collection_character": {"character_id": "uuid", "uncap_level": 3}}'

   # Create a weapon
   curl -X POST http://localhost:3000/api/v1/collection/weapons \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"collection_weapon": {"weapon_id": "uuid", "uncap_level": 4}}'
   ```

## Deployment Checklist

- [ ] Run all migrations in staging
- [ ] Test all endpoints in staging
- [ ] Verify database indexes are created
- [ ] Test with large datasets
- [ ] Set up error tracking (Sentry/Rollbar)
- [ ] Create backup before deployment
- [ ] Prepare rollback plan
- [ ] Update API documentation
- [ ] Notify frontend team of new endpoints
- [ ] Schedule deployment during low-traffic window
- [ ] Monitor application after deployment

## API Endpoint Summary

### Public Collection Viewing (Respects Privacy Settings)
- `GET /api/v1/users/:user_id/collection` - View complete collection (if not private)
- `GET /api/v1/users/:user_id/collection?type=characters` - View characters only (if not private)
- `GET /api/v1/users/:user_id/collection?type=weapons` - View weapons only (if not private)
- `GET /api/v1/users/:user_id/collection?type=summons` - View summons only (if not private)
- `GET /api/v1/users/:user_id/collection?type=job_accessories` - View job accessories only (if not private)
- `GET /api/v1/users/:user_id/collection/statistics` - View collection statistics (if not private)

### Collection Management (Authentication Required)
- `GET/POST/PUT/DELETE /api/v1/collection/characters` - Manage character collection
- `GET/POST/PUT/DELETE /api/v1/collection/weapons` - Manage weapon collection
- `GET/POST/PUT/DELETE /api/v1/collection/summons` - Manage summon collection
- `GET/POST/DELETE /api/v1/collection/job_accessories` - Manage job accessory collection

### Privacy Settings (Authentication Required)
To update collection privacy settings, use the existing user update endpoint:
- `PUT /api/v1/users/:id` - Update user settings including `collection_privacy` field

Privacy levels:
- `0` or `"public"`: Collection is viewable by everyone
- `1` or `"crew_only"`: Collection is viewable only by crew members (when crew feature is implemented)
- `2` or `"private"`: Collection is viewable only by the owner

Example request:
```json
{
  "user": {
    "collection_privacy": "crew_only"
  }
}
```