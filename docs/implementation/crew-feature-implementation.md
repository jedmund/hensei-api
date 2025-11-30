# Crew Feature Implementation Guide

## Prerequisites

- Rails 8.0.1 environment
- PostgreSQL database
- Existing user authentication system
- Collection tracking feature implemented (for privacy integration)

## Step-by-Step Implementation

### Step 1: Database Migrations

#### 1.1 Create Crews table

```bash
rails generate migration CreateCrews
```

```ruby
# db/migrate/xxx_create_crews.rb
class CreateCrews < ActiveRecord::Migration[8.0]
  def change
    create_table :crews, id: :uuid do |t|
      t.string :name, null: false
      t.references :captain, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :gamertag, limit: 4
      t.text :rules
      t.integer :member_count, default: 1, null: false

      t.timestamps
    end

    add_index :crews, :name, unique: true
    add_index :crews, :gamertag, unique: true, where: "gamertag IS NOT NULL"
    add_index :crews, :created_at
  end
end
```

#### 1.2 Create CrewMemberships table

```bash
rails generate migration CreateCrewMemberships
```

```ruby
# db/migrate/xxx_create_crew_memberships.rb
class CreateCrewMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :crew_memberships, id: :uuid do |t|
      t.references :crew, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.integer :role, default: 0, null: false # 0=member, 1=subcaptain, 2=captain
      t.boolean :display_gamertag, default: true, null: false
      t.datetime :joined_at, default: -> { 'CURRENT_TIMESTAMP' }, null: false

      t.timestamps
    end

    add_index :crew_memberships, [:crew_id, :user_id], unique: true
    add_index :crew_memberships, :role
    add_index :crew_memberships, :joined_at

    # Add constraint to limit subcaptains to 3 per crew
    execute <<-SQL
      CREATE OR REPLACE FUNCTION check_subcaptain_limit() RETURNS TRIGGER AS $$
      BEGIN
        IF NEW.role = 1 THEN
          IF (SELECT COUNT(*) FROM crew_memberships
              WHERE crew_id = NEW.crew_id AND role = 1 AND id != NEW.id) >= 3 THEN
            RAISE EXCEPTION 'Maximum 3 subcaptains allowed per crew';
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER enforce_subcaptain_limit
      BEFORE INSERT OR UPDATE ON crew_memberships
      FOR EACH ROW EXECUTE FUNCTION check_subcaptain_limit();
    SQL

    # Add constraint to limit crew size to 30 members
    execute <<-SQL
      CREATE OR REPLACE FUNCTION check_crew_member_limit() RETURNS TRIGGER AS $$
      BEGIN
        IF (SELECT COUNT(*) FROM crew_memberships WHERE crew_id = NEW.crew_id) >= 30 THEN
          RAISE EXCEPTION 'Maximum 30 members allowed per crew';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER enforce_crew_member_limit
      BEFORE INSERT ON crew_memberships
      FOR EACH ROW EXECUTE FUNCTION check_crew_member_limit();
    SQL
  end
end
```

#### 1.3 Create CrewInvitations table

```bash
rails generate migration CreateCrewInvitations
```

```ruby
# db/migrate/xxx_create_crew_invitations.rb
class CreateCrewInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :crew_invitations, id: :uuid do |t|
      t.references :crew, type: :uuid, null: false, foreign_key: true
      t.references :invited_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :token, null: false
      t.datetime :expires_at, default: -> { "CURRENT_TIMESTAMP + INTERVAL '7 days'" }, null: false
      t.datetime :used_at
      t.references :used_by, type: :uuid, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :crew_invitations, :token, unique: true
    add_index :crew_invitations, :expires_at
    add_index :crew_invitations, [:crew_id, :used_at]
  end
end
```

#### 1.4 Create UniteAndFights table

```bash
rails generate migration CreateUniteAndFights
```

```ruby
# db/migrate/xxx_create_unite_and_fights.rb
class CreateUniteAndFights < ActiveRecord::Migration[8.0]
  def change
    create_table :unite_and_fights, id: :uuid do |t|
      t.string :name, null: false
      t.integer :event_number, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.references :created_by, type: :uuid, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :unite_and_fights, :event_number, unique: true
    add_index :unite_and_fights, :starts_at
    add_index :unite_and_fights, :ends_at
    add_index :unite_and_fights, [:starts_at, :ends_at]
  end
end
```

#### 1.5 Create UnfScores table

```bash
rails generate migration CreateUnfScores
```

```ruby
# db/migrate/xxx_create_unf_scores.rb
class CreateUnfScores < ActiveRecord::Migration[8.0]
  def change
    create_table :unf_scores, id: :uuid do |t|
      t.references :unite_and_fight, type: :uuid, null: false, foreign_key: true
      t.references :crew, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.bigint :honors, default: 0, null: false
      t.references :recorded_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.integer :day_number, null: false # 1-7 for each day of the event

      t.timestamps
    end

    add_index :unf_scores, [:unite_and_fight_id, :crew_id, :user_id, :day_number],
              unique: true, name: 'idx_unf_scores_unique'
    add_index :unf_scores, [:crew_id, :unite_and_fight_id]
    add_index :unf_scores, :honors

    # Validate day_number is between 1 and 7
    execute <<-SQL
      ALTER TABLE unf_scores
      ADD CONSTRAINT check_day_number
      CHECK (day_number >= 1 AND day_number <= 7);
    SQL
  end
end
```

#### 1.6 Update Users table for crew association

```bash
rails generate migration AddCrewIdToUsers
```

```ruby
# db/migrate/xxx_add_crew_id_to_users.rb
class AddCrewIdToUsers < ActiveRecord::Migration[8.0]
  def change
    # Note: We don't add crew_id directly to users table
    # The relationship is through crew_memberships table
    # This migration is for updating collection_viewable_by? logic

    # Update the collection_viewable_by method in User model to check crew membership
  end
end
```

### Step 2: Create Models

#### 2.1 Crew model

```ruby
# app/models/crew.rb
class Crew < ApplicationRecord
  # Associations
  belongs_to :captain, class_name: 'User'
  has_many :crew_memberships, dependent: :destroy
  has_many :members, through: :crew_memberships, source: :user
  has_many :crew_invitations, dependent: :destroy
  has_many :unf_scores, dependent: :destroy

  # Scopes for specific roles
  has_many :subcaptains, -> { where(crew_memberships: { role: 1 }) },
           through: :crew_memberships, source: :user

  # Validations
  validates :name, presence: true, uniqueness: true,
            length: { minimum: 2, maximum: 30 }
  validates :gamertag, length: { is: 4 }, allow_blank: true,
            uniqueness: { case_sensitive: false },
            format: { with: /\A[A-Z0-9]+\z/i, message: "only alphanumeric characters allowed" }
  validates :rules, length: { maximum: 5000 }
  validates :member_count, numericality: { greater_than: 0, less_than_or_equal_to: 30 }

  # Callbacks
  after_create :create_captain_membership

  # Methods
  def full?
    member_count >= 30
  end

  def has_subcaptain_slots?
    crew_memberships.where(role: 1).count < 3
  end

  def active_invitations
    crew_invitations.where(used_at: nil).where('expires_at > ?', Time.current)
  end

  def subcaptain_count
    crew_memberships.where(role: 1).count
  end

  def blueprint
    CrewBlueprint
  end

  private

  def create_captain_membership
    crew_memberships.create!(
      user: captain,
      role: 2, # captain role
      display_gamertag: true
    )
  end
end
```

#### 2.2 CrewMembership model

```ruby
# app/models/crew_membership.rb
class CrewMembership < ApplicationRecord
  # Associations
  belongs_to :crew, counter_cache: :member_count
  belongs_to :user

  # Enums
  enum role: {
    member: 0,
    subcaptain: 1,
    captain: 2
  }

  # Validations
  validates :user_id, uniqueness: { scope: :crew_id,
    message: "is already a member of this crew" }
  validate :validate_subcaptain_limit, if: :subcaptain?
  validate :validate_single_crew_membership, on: :create

  # Scopes
  scope :officers, -> { where(role: [1, 2]) } # subcaptains and captain
  scope :by_join_date, -> { order(joined_at: :asc) }
  scope :displaying_gamertag, -> { where(display_gamertag: true) }

  # Callbacks
  before_validation :set_joined_at, on: :create

  def blueprint
    CrewMembershipBlueprint
  end

  private

  def validate_subcaptain_limit
    return unless role_changed? && subcaptain?

    if crew.subcaptain_count >= 3
      errors.add(:role, "Maximum 3 subcaptains allowed per crew")
    end
  end

  def validate_single_crew_membership
    if user.crew_membership.present?
      errors.add(:user, "is already a member of another crew")
    end
  end

  def set_joined_at
    self.joined_at ||= Time.current
  end
end
```

#### 2.3 CrewInvitation model

```ruby
# app/models/crew_invitation.rb
class CrewInvitation < ApplicationRecord
  # Associations
  belongs_to :crew
  belongs_to :invited_by, class_name: 'User'
  belongs_to :used_by, class_name: 'User', optional: true

  # Validations
  validates :token, presence: true, uniqueness: true
  validate :crew_not_full, on: :create

  # Callbacks
  before_validation :generate_token, on: :create
  before_create :set_expiration

  # Scopes
  scope :active, -> { where(used_at: nil).where('expires_at > ?', Time.current) }
  scope :expired, -> { where(used_at: nil).where('expires_at <= ?', Time.current) }
  scope :used, -> { where.not(used_at: nil) }

  def expired?
    expires_at < Time.current
  end

  def used?
    used_at.present?
  end

  def valid_for_use?
    !expired? && !used? && !crew.full?
  end

  def use_by!(user)
    return false unless valid_for_use?
    return false if user.crew_membership.present?

    transaction do
      update!(used_at: Time.current, used_by: user)
      crew.crew_memberships.create!(user: user, role: :member)
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def invitation_url
    "#{Rails.application.config.frontend_url}/crews/join?token=#{token}"
  end

  def blueprint
    CrewInvitationBlueprint
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at ||= 7.days.from_now
  end

  def crew_not_full
    errors.add(:crew, "is already full") if crew.full?
  end
end
```

#### 2.4 UniteAndFight model

```ruby
# app/models/unite_and_fight.rb
class UniteAndFight < ApplicationRecord
  # Associations
  has_many :unf_scores, dependent: :destroy
  belongs_to :created_by, class_name: 'User'

  # Validations
  validates :name, presence: true
  validates :event_number, presence: true, uniqueness: true,
            numericality: { greater_than: 0 }
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validate :end_after_start
  validate :duration_is_one_week

  # Scopes
  scope :current, -> { where('starts_at <= ? AND ends_at >= ?', Time.current, Time.current) }
  scope :upcoming, -> { where('starts_at > ?', Time.current).order(starts_at: :asc) }
  scope :past, -> { where('ends_at < ?', Time.current).order(ends_at: :desc) }

  def active?
    starts_at <= Time.current && ends_at >= Time.current
  end

  def upcoming?
    starts_at > Time.current
  end

  def past?
    ends_at < Time.current
  end

  def day_number_for(date = Date.current)
    return nil unless date.between?(starts_at.to_date, ends_at.to_date)
    (date - starts_at.to_date).to_i + 1
  end

  def blueprint
    UniteAndFightBlueprint
  end

  private

  def end_after_start
    return unless starts_at && ends_at
    errors.add(:ends_at, "must be after start date") if ends_at <= starts_at
  end

  def duration_is_one_week
    return unless starts_at && ends_at
    duration = (ends_at - starts_at).to_i / 1.day
    errors.add(:base, "Event must last exactly 7 days") unless duration == 7
  end
end
```

#### 2.5 UnfScore model

```ruby
# app/models/unf_score.rb
class UnfScore < ApplicationRecord
  # Associations
  belongs_to :unite_and_fight
  belongs_to :crew
  belongs_to :user
  belongs_to :recorded_by, class_name: 'User'

  # Validations
  validates :honors, presence: true,
            numericality: { greater_than_or_equal_to: 0 }
  validates :day_number, presence: true,
            inclusion: { in: 1..7 }
  validates :user_id, uniqueness: {
    scope: [:unite_and_fight_id, :crew_id, :day_number],
    message: "already has a score for this day"
  }
  validate :user_is_crew_member
  validate :day_within_event

  # Scopes
  scope :for_event, ->(event) { where(unite_and_fight: event) }
  scope :for_crew, ->(crew) { where(crew: crew) }
  scope :for_user, ->(user) { where(user: user) }
  scope :by_day, ->(day) { where(day_number: day) }
  scope :total_honors, -> { sum(:honors) }

  # Class methods for aggregation
  def self.user_totals_for_event(event, crew)
    for_event(event)
      .for_crew(crew)
      .group(:user_id)
      .sum(:honors)
      .sort_by { |_user_id, honors| -honors }
  end

  def self.daily_totals_for_crew(event, crew)
    for_event(event)
      .for_crew(crew)
      .group(:day_number)
      .sum(:honors)
  end

  def blueprint
    UnfScoreBlueprint
  end

  private

  def user_is_crew_member
    return unless user && crew
    unless user.member_of?(crew)
      errors.add(:user, "must be a member of the crew")
    end
  end

  def day_within_event
    return unless unite_and_fight && day_number
    max_day = unite_and_fight.day_number_for(unite_and_fight.ends_at.to_date)
    if day_number > max_day
      errors.add(:day_number, "exceeds event duration")
    end
  end
end
```

#### 2.6 Update User model

```ruby
# app/models/user.rb - Add these associations and methods

# Associations
has_one :crew_membership, dependent: :destroy
has_one :crew, through: :crew_membership
has_many :captained_crews, class_name: 'Crew', foreign_key: :captain_id
has_many :crew_invitations_sent, class_name: 'CrewInvitation', foreign_key: :invited_by_id
has_many :unf_scores
has_many :recorded_unf_scores, class_name: 'UnfScore', foreign_key: :recorded_by_id

# Crew role checking methods
def captain_of?(crew)
  crew.captain_id == id
end

def subcaptain_of?(crew)
  crew_membership&.subcaptain? && crew_membership.crew_id == crew.id
end

def member_of?(crew)
  crew_membership&.crew_id == crew.id
end

def can_manage_crew?(crew)
  captain_of?(crew) || subcaptain_of?(crew)
end

def can_invite_to_crew?(crew)
  can_manage_crew?(crew)
end

def can_remove_from_crew?(crew)
  captain_of?(crew)
end

def can_record_unf_scores?(crew)
  can_manage_crew?(crew)
end

def in_same_crew_as?(other_user)
  return false unless other_user.present? && crew_membership.present?
  crew_membership.crew_id == other_user.crew_membership&.crew_id
end

# Update collection_viewable_by? to support crew_only privacy
def collection_viewable_by?(viewer)
  return true if self == viewer

  case collection_privacy
  when 'public'
    true
  when 'crew_only'
    viewer.present? && in_same_crew_as?(viewer)
  when 'private'
    false
  else
    false
  end
end
```

### Step 3: Create Blueprints

#### 3.1 CrewBlueprint

```ruby
# app/blueprints/api/v1/crew_blueprint.rb
module Api
  module V1
    class CrewBlueprint < ApiBlueprint
      identifier :id

      fields :name, :gamertag, :rules, :member_count,
             :created_at, :updated_at

      association :captain, blueprint: UserBlueprint, view: :basic

      view :with_members do
        association :members, blueprint: UserBlueprint, view: :basic do |crew, options|
          crew.crew_memberships.includes(:user).map do |membership|
            {
              user: UserBlueprint.render_as_hash(membership.user, view: :basic),
              role: membership.role,
              joined_at: membership.joined_at,
              display_gamertag: membership.display_gamertag
            }
          end
        end
      end

      view :full do
        include_view :with_members
        field :subcaptain_slots_available do |crew|
          3 - crew.subcaptain_count
        end
        field :is_full do |crew|
          crew.full?
        end
      end
    end
  end
end
```

#### 3.2 CrewMembershipBlueprint

```ruby
# app/blueprints/api/v1/crew_membership_blueprint.rb
module Api
  module V1
    class CrewMembershipBlueprint < ApiBlueprint
      identifier :id

      fields :role, :display_gamertag, :joined_at,
             :created_at, :updated_at

      association :user, blueprint: UserBlueprint, view: :basic
      association :crew, blueprint: CrewBlueprint

      view :full do
        association :crew, blueprint: CrewBlueprint, view: :with_members
      end
    end
  end
end
```

#### 3.3 CrewInvitationBlueprint

```ruby
# app/blueprints/api/v1/crew_invitation_blueprint.rb
module Api
  module V1
    class CrewInvitationBlueprint < ApiBlueprint
      identifier :id

      fields :token, :expires_at, :used_at, :created_at

      field :invitation_url do |invitation|
        invitation.invitation_url
      end

      field :is_expired do |invitation|
        invitation.expired?
      end

      field :is_used do |invitation|
        invitation.used?
      end

      association :invited_by, blueprint: UserBlueprint, view: :basic
      association :used_by, blueprint: UserBlueprint, view: :basic,
                  if: ->(_, invitation, _) { invitation.used_by.present? }

      view :full do
        association :crew, blueprint: CrewBlueprint
      end
    end
  end
end
```

#### 3.4 UniteAndFightBlueprint

```ruby
# app/blueprints/api/v1/unite_and_fight_blueprint.rb
module Api
  module V1
    class UniteAndFightBlueprint < ApiBlueprint
      identifier :id

      fields :name, :event_number, :starts_at, :ends_at,
             :created_at, :updated_at

      field :status do |unf|
        if unf.active?
          'active'
        elsif unf.upcoming?
          'upcoming'
        else
          'past'
        end
      end

      field :current_day do |unf|
        unf.day_number_for(Date.current) if unf.active?
      end

      association :created_by, blueprint: UserBlueprint, view: :basic
    end
  end
end
```

#### 3.5 UnfScoreBlueprint

```ruby
# app/blueprints/api/v1/unf_score_blueprint.rb
module Api
  module V1
    class UnfScoreBlueprint < ApiBlueprint
      identifier :id

      fields :honors, :day_number, :created_at, :updated_at

      association :user, blueprint: UserBlueprint, view: :basic
      association :recorded_by, blueprint: UserBlueprint, view: :basic

      view :with_event do
        association :unite_and_fight, blueprint: UniteAndFightBlueprint
      end

      view :with_crew do
        association :crew, blueprint: CrewBlueprint
      end

      view :full do
        include_view :with_event
        include_view :with_crew
      end
    end
  end
end
```

### Step 4: Create Controllers

#### 4.1 CrewsController

```ruby
# app/controllers/api/v1/crews_controller.rb
module Api
  module V1
    class CrewsController < ApiController
      before_action :authenticate_user!, except: [:show]
      before_action :set_crew, only: [:show, :update, :destroy]
      before_action :authorize_captain!, only: [:destroy]
      before_action :authorize_manager!, only: [:update]

      def create
        @crew = Crew.new(crew_params)
        @crew.captain = current_user

        if current_user.crew_membership.present?
          render json: { error: "You are already a member of a crew" },
                 status: :unprocessable_entity
          return
        end

        if @crew.save
          render json: CrewBlueprint.render(@crew, view: :full), status: :created
        else
          render_errors(@crew.errors)
        end
      end

      def show
        render json: CrewBlueprint.render(@crew, view: :full)
      end

      def update
        if @crew.update(crew_params)
          render json: CrewBlueprint.render(@crew, view: :full)
        else
          render_errors(@crew.errors)
        end
      end

      def destroy
        @crew.destroy
        head :no_content
      end

      def my
        authenticate_user!

        if current_user.crew
          render json: CrewBlueprint.render(current_user.crew, view: :full)
        else
          render json: { error: "You are not a member of any crew" },
                 status: :not_found
        end
      end

      private

      def set_crew
        @crew = Crew.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Crew not found" }, status: :not_found
      end

      def crew_params
        params.require(:crew).permit(:name, :rules, :gamertag)
      end

      def authorize_captain!
        unless current_user.captain_of?(@crew)
          render json: { error: "Only the captain can perform this action" },
                 status: :forbidden
        end
      end

      def authorize_manager!
        unless current_user.can_manage_crew?(@crew)
          render json: { error: "You don't have permission to manage this crew" },
                 status: :forbidden
        end
      end
    end
  end
end
```

#### 4.2 CrewMembersController

```ruby
# app/controllers/api/v1/crew_members_controller.rb
module Api
  module V1
    class CrewMembersController < ApiController
      before_action :authenticate_user!
      before_action :set_crew
      before_action :set_member, only: [:destroy]
      before_action :authorize_captain!, only: [:promote, :destroy]

      def index
        @memberships = @crew.crew_memberships
                           .includes(:user)
                           .by_join_date
                           .page(params[:page])
                           .per(params[:limit] || 30)

        render json: CrewMembershipBlueprint.render(
          @memberships,
          root: :members,
          meta: pagination_meta(@memberships)
        )
      end

      def promote
        @member = @crew.members.find(params[:user_id])
        @membership = @crew.crew_memberships.find_by(user: @member)

        if params[:role] == 'subcaptain'
          unless @crew.has_subcaptain_slots?
            render json: { error: "Maximum subcaptains reached" },
                   status: :unprocessable_entity
            return
          end

          @membership.subcaptain!
          render json: CrewMembershipBlueprint.render(@membership)
        elsif params[:role] == 'member'
          @membership.member!
          render json: CrewMembershipBlueprint.render(@membership)
        else
          render json: { error: "Invalid role" }, status: :unprocessable_entity
        end
      end

      def destroy
        if @member == @crew.captain
          render json: { error: "Cannot remove the captain" },
                 status: :unprocessable_entity
          return
        end

        @membership = @crew.crew_memberships.find_by(user: @member)
        @membership.destroy
        head :no_content
      end

      def update_me
        @membership = current_user.crew_membership

        unless @membership && @membership.crew_id == @crew.id
          render json: { error: "You are not a member of this crew" },
                 status: :forbidden
          return
        end

        if @membership.update(my_membership_params)
          render json: CrewMembershipBlueprint.render(@membership)
        else
          render_errors(@membership.errors)
        end
      end

      def leave
        @membership = current_user.crew_membership

        unless @membership && @membership.crew_id == @crew.id
          render json: { error: "You are not a member of this crew" },
                 status: :forbidden
          return
        end

        if @membership.captain?
          render json: { error: "Captain cannot leave the crew. Transfer ownership or disband the crew." },
                 status: :unprocessable_entity
          return
        end

        @membership.destroy
        head :no_content
      end

      private

      def set_crew
        @crew = Crew.find(params[:crew_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Crew not found" }, status: :not_found
      end

      def set_member
        @member = User.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Member not found" }, status: :not_found
      end

      def my_membership_params
        params.permit(:display_gamertag)
      end

      def authorize_captain!
        unless current_user.captain_of?(@crew)
          render json: { error: "Only the captain can perform this action" },
                 status: :forbidden
        end
      end
    end
  end
end
```

#### 4.3 CrewInvitationsController

```ruby
# app/controllers/api/v1/crew_invitations_controller.rb
module Api
  module V1
    class CrewInvitationsController < ApiController
      before_action :authenticate_user!
      before_action :set_crew, except: [:join]
      before_action :authorize_inviter!, except: [:join]

      def create
        if @crew.full?
          render json: { error: "Crew is full" }, status: :unprocessable_entity
          return
        end

        @invitation = @crew.crew_invitations.build(invited_by: current_user)

        if @invitation.save
          render json: CrewInvitationBlueprint.render(@invitation, view: :full),
                 status: :created
        else
          render_errors(@invitation.errors)
        end
      end

      def index
        @invitations = @crew.active_invitations
                           .includes(:invited_by, :used_by)
                           .page(params[:page])
                           .per(params[:limit] || 20)

        render json: CrewInvitationBlueprint.render(
          @invitations,
          root: :invitations,
          meta: pagination_meta(@invitations)
        )
      end

      def destroy
        @invitation = @crew.crew_invitations.find(params[:id])

        if @invitation.used?
          render json: { error: "Cannot revoke a used invitation" },
                 status: :unprocessable_entity
          return
        end

        @invitation.destroy
        head :no_content
      end

      def join
        @invitation = CrewInvitation.find_by(token: params[:token])

        unless @invitation
          render json: { error: "Invalid invitation" }, status: :not_found
          return
        end

        unless @invitation.valid_for_use?
          error = if @invitation.expired?
                    "Invitation has expired"
                  elsif @invitation.used?
                    "Invitation has already been used"
                  else
                    "Crew is full"
                  end
          render json: { error: error }, status: :unprocessable_entity
          return
        end

        if current_user.crew_membership.present?
          render json: { error: "You are already a member of a crew" },
                 status: :unprocessable_entity
          return
        end

        if @invitation.use_by!(current_user)
          render json: CrewBlueprint.render(@invitation.crew, view: :full)
        else
          render json: { error: "Failed to join crew" },
                 status: :unprocessable_entity
        end
      end

      private

      def set_crew
        @crew = Crew.find(params[:crew_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Crew not found" }, status: :not_found
      end

      def authorize_inviter!
        unless current_user.can_invite_to_crew?(@crew)
          render json: { error: "You don't have permission to manage invitations" },
                 status: :forbidden
        end
      end
    end
  end
end
```

#### 4.4 UniteAndFightsController

```ruby
# app/controllers/api/v1/unite_and_fights_controller.rb
module Api
  module V1
    class UniteAndFightsController < ApiController
      before_action :authenticate_user!, except: [:index, :show]
      before_action :require_admin!, only: [:create, :update, :destroy]
      before_action :set_unite_and_fight, only: [:show, :update, :destroy]

      def index
        @unite_and_fights = UniteAndFight.all.order(event_number: :desc)

        @unite_and_fights = case params[:status]
        when 'current'
          @unite_and_fights.current
        when 'upcoming'
          @unite_and_fights.upcoming
        when 'past'
          @unite_and_fights.past
        else
          @unite_and_fights
        end

        @unite_and_fights = @unite_and_fights.page(params[:page]).per(params[:limit] || 20)

        render json: UniteAndFightBlueprint.render(
          @unite_and_fights,
          root: :unite_and_fights,
          meta: pagination_meta(@unite_and_fights)
        )
      end

      def show
        render json: UniteAndFightBlueprint.render(@unite_and_fight)
      end

      def create
        @unite_and_fight = UniteAndFight.new(unite_and_fight_params)
        @unite_and_fight.created_by = current_user

        if @unite_and_fight.save
          render json: UniteAndFightBlueprint.render(@unite_and_fight),
                 status: :created
        else
          render_errors(@unite_and_fight.errors)
        end
      end

      def update
        if @unite_and_fight.update(unite_and_fight_params)
          render json: UniteAndFightBlueprint.render(@unite_and_fight)
        else
          render_errors(@unite_and_fight.errors)
        end
      end

      def destroy
        @unite_and_fight.destroy
        head :no_content
      end

      private

      def set_unite_and_fight
        @unite_and_fight = UniteAndFight.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Unite and Fight event not found" }, status: :not_found
      end

      def unite_and_fight_params
        params.require(:unite_and_fight).permit(:name, :event_number, :starts_at, :ends_at)
      end

      def require_admin!
        unless current_user.role >= 7
          render json: { error: "Admin access required" }, status: :forbidden
        end
      end
    end
  end
end
```

#### 4.5 UnfScoresController

```ruby
# app/controllers/api/v1/unf_scores_controller.rb
module Api
  module V1
    class UnfScoresController < ApiController
      before_action :authenticate_user!
      before_action :set_crew, except: [:performance]
      before_action :authorize_scorer!, only: [:create, :update]

      def create
        @unf_score = UnfScore.find_or_initialize_by(
          unite_and_fight_id: params[:unite_and_fight_id],
          crew_id: @crew.id,
          user_id: params[:user_id],
          day_number: params[:day_number]
        )

        @unf_score.honors = params[:honors]
        @unf_score.recorded_by = current_user

        if @unf_score.save
          render json: UnfScoreBlueprint.render(@unf_score, view: :full),
                 status: :created
        else
          render_errors(@unf_score.errors)
        end
      end

      def index
        @scores = @crew.unf_scores.includes(:user, :unite_and_fight, :recorded_by)

        if params[:unite_and_fight_id]
          @scores = @scores.where(unite_and_fight_id: params[:unite_and_fight_id])
        end

        if params[:user_id]
          @scores = @scores.where(user_id: params[:user_id])
        end

        if params[:day_number]
          @scores = @scores.where(day_number: params[:day_number])
        end

        @scores = @scores.order(day_number: :asc, honors: :desc)
                        .page(params[:page])
                        .per(params[:limit] || 50)

        render json: UnfScoreBlueprint.render(
          @scores,
          root: :scores,
          meta: pagination_meta(@scores)
        )
      end

      def performance
        authenticate_user!

        crew_id = params[:crew_id]
        unless crew_id
          render json: { error: "crew_id is required" }, status: :bad_request
          return
        end

        @crew = Crew.find(crew_id)

        # Check if user can view crew scores
        unless current_user.member_of?(@crew)
          render json: { error: "You must be a crew member to view scores" },
                 status: :forbidden
          return
        end

        # Build performance query
        scores = UnfScore.for_crew(@crew)

        if params[:user_id]
          scores = scores.for_user(params[:user_id])
        end

        if params[:from_date]
          from_date = Date.parse(params[:from_date])
          events = UniteAndFight.where('ends_at >= ?', from_date)
          scores = scores.where(unite_and_fight: events)
        end

        if params[:to_date]
          to_date = Date.parse(params[:to_date])
          events = UniteAndFight.where('starts_at <= ?', to_date)
          scores = scores.where(unite_and_fight: events)
        end

        # Group by event and aggregate
        performance_data = scores.includes(:unite_and_fight, :user)
                                 .group_by(&:unite_and_fight)
                                 .map do |event, event_scores|
          {
            event: UniteAndFightBlueprint.render_as_hash(event),
            total_honors: event_scores.sum(&:honors),
            daily_totals: event_scores.group_by(&:day_number)
                                     .transform_values { |s| s.sum(&:honors) },
            user_totals: event_scores.group_by(&:user)
                                    .transform_keys { |u| u.id }
                                    .transform_values { |s| s.sum(&:honors) }
          }
        end

        render json: { performance: performance_data }
      end

      private

      def set_crew
        @crew = Crew.find(params[:crew_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Crew not found" }, status: :not_found
      end

      def authorize_scorer!
        unless current_user.can_record_unf_scores?(@crew)
          render json: { error: "You don't have permission to record scores" },
                 status: :forbidden
        end
      end
    end
  end
end
```

### Step 5: Update Routes

```ruby
# config/routes.rb - Add these routes within the API scope

# Crew management
resources :crews, only: [:create, :show, :update, :destroy] do
  collection do
    get 'my', to: 'crews#my'
  end

  # Crew members
  resources :members, controller: 'crew_members', only: [:index, :destroy] do
    collection do
      post 'promote'
      put 'me', to: 'crew_members#update_me'
      delete 'leave', to: 'crew_members#leave'
    end
  end

  # Invitations
  resources :invitations, controller: 'crew_invitations', only: [:create, :index, :destroy]

  # UnF scores for this crew
  resources :unf_scores, only: [:create, :index]
end

# Join crew via invitation
post 'crews/join', to: 'crew_invitations#join'

# Unite and Fight events
resources :unite_and_fights

# UnF score performance analytics
get 'unf_scores/performance', to: 'unf_scores#performance'
```

### Step 6: Add Authorization Concerns

```ruby
# app/controllers/concerns/crew_authorization_concern.rb
module CrewAuthorizationConcern
  extend ActiveSupport::Concern

  private

  def require_crew_membership
    unless current_user.crew_membership.present?
      render json: { error: "You must be a member of a crew" }, status: :forbidden
      false
    end
  end

  def require_crew_captain
    return false unless require_crew_membership

    unless current_user.crew_membership.captain?
      render json: { error: "Only the captain can perform this action" },
             status: :forbidden
      false
    end
  end

  def require_crew_manager
    return false unless require_crew_membership

    unless current_user.crew_membership.captain? || current_user.crew_membership.subcaptain?
      render json: { error: "Only captains and subcaptains can perform this action" },
             status: :forbidden
      false
    end
  end
end
```

## Testing the Implementation

### Manual Testing Steps

1. **Create a crew**
```bash
curl -X POST http://localhost:3000/api/v1/crews \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"crew": {"name": "Test Crew", "gamertag": "TEST"}}'
```

2. **Generate invitation**
```bash
curl -X POST http://localhost:3000/api/v1/crews/CREW_ID/invitations \
  -H "Authorization: Bearer YOUR_TOKEN"
```

3. **Join crew**
```bash
curl -X POST http://localhost:3000/api/v1/crews/join \
  -H "Authorization: Bearer OTHER_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"token": "INVITATION_TOKEN"}'
```

4. **Promote to subcaptain**
```bash
curl -X POST http://localhost:3000/api/v1/crews/CREW_ID/members/promote \
  -H "Authorization: Bearer CAPTAIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "USER_ID", "role": "subcaptain"}'
```

5. **Record UnF score**
```bash
curl -X POST http://localhost:3000/api/v1/crews/CREW_ID/unf_scores \
  -H "Authorization: Bearer CAPTAIN_OR_SUBCAPTAIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "unite_and_fight_id": "UNF_ID",
    "user_id": "MEMBER_ID",
    "honors": 1000000,
    "day_number": 1
  }'
```

## Deployment Checklist

- [ ] Run all migrations in order
- [ ] Verify database constraints are created
- [ ] Test crew size limits (30 members)
- [ ] Test subcaptain limits (3 per crew)
- [ ] Verify invitation expiration
- [ ] Test UnF score recording
- [ ] Verify collection privacy integration
- [ ] Set up background job for invitation cleanup
- [ ] Configure rate limiting for invitations
- [ ] Update API documentation
- [ ] Deploy frontend changes
- [ ] Monitor for performance issues
- [ ] Prepare rollback plan

## Performance Optimizations

1. **Add caching for crew member lists**
```ruby
def members_cache_key
  "crew_#{id}_members_#{updated_at}"
end
```

2. **Background job for expired invitations cleanup**
```ruby
class CleanupExpiredInvitationsJob < ApplicationJob
  def perform
    CrewInvitation.expired.destroy_all
  end
end
```

3. **Optimize UnF score queries**
```ruby
# Add composite indexes for common query patterns
add_index :unf_scores, [:crew_id, :unite_and_fight_id, :user_id]
add_index :unf_scores, [:unite_and_fight_id, :honors]
```

## Next Steps

1. Implement crew feed functionality
2. Add real-time notifications for crew events
3. Create crew chat system
4. Build crew discovery and recruitment features
5. Add crew achievements and milestones
6. Implement crew-vs-crew competitions
7. Create mobile push notifications
8. Add crew resource sharing system