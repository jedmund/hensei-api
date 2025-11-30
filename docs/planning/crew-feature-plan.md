# Crew Feature Plan

## Overview

The Crew system enables players to form groups of up to 30 members to collaborate, share strategies, and compete in Unite and Fight events. Crews provide a social layer to the application with hierarchical roles, shared content visibility, and performance tracking capabilities.

## Business Requirements

### Core Concepts

#### Crew Structure
- **Size Limit**: Maximum 30 members per crew
- **Roles Hierarchy**:
  - **Captain**: The crew creator with full administrative privileges
  - **Subcaptains**: Up to 3 members with elevated permissions
  - **Members**: Regular crew participants with standard access

#### Key Features
1. **Crew Management**: Creation, invitation, membership control
2. **Gamertags**: 4-character tags displayed alongside member names
3. **Unite and Fight**: Event participation and score tracking
4. **Crew Feed**: Private content stream for crew-only parties, guides, and future posts
5. **Performance Analytics**: Historical tracking and visualization of member contributions

### User Stories

#### As a Captain
- I want to create a crew and invite players to join
- I want to appoint up to 3 subcaptains to help manage the crew
- I want to remove members who are inactive or problematic
- I want to set crew rules that all members can view
- I want to track member performance in Unite and Fight events

#### As a Subcaptain
- I want to help manage crew by inviting new members
- I want to update crew rules and information
- I want to record Unite and Fight scores for members
- I want to set gamertags for crew representation

#### As a Member
- I want to join a crew via invitation link
- I want to view crew rules and information
- I want to see my Unite and Fight performance history
- I want to choose whether to display my crew's gamertag
- I want to see crew-only parties and guides in the feed

#### As a System Administrator
- I want to add new Unite and Fight events when announced by Cygames
- I want to manage event dates and parameters
- I want to monitor crew activities for policy violations

## Technical Design

### Database Schema

#### crews
```sql
- id: uuid (primary key)
- name: string (unique, not null)
- captain_id: uuid (foreign key to users, not null)
- gamertag: string (4 characters, unique, can be null)
- rules: text
- member_count: integer (counter cache, default 1)
- created_at: timestamp
- updated_at: timestamp

Indexes:
- unique index on name
- unique index on gamertag (where not null)
- index on captain_id
- index on created_at
```

#### crew_memberships
```sql
- id: uuid (primary key)
- crew_id: uuid (foreign key to crews, not null)
- user_id: uuid (foreign key to users, not null)
- role: integer (0=member, 1=subcaptain, 2=captain)
- display_gamertag: boolean (default true)
- joined_at: timestamp (default now)
- created_at: timestamp
- updated_at: timestamp

Indexes:
- unique index on [crew_id, user_id]
- index on crew_id
- index on user_id
- index on role
- index on joined_at
```

#### crew_invitations
```sql
- id: uuid (primary key)
- crew_id: uuid (foreign key to crews, not null)
- invited_by_id: uuid (foreign key to users, not null)
- token: string (unique, not null)
- expires_at: timestamp (default 7 days from creation)
- used_at: timestamp (null)
- used_by_id: uuid (foreign key to users, null)
- created_at: timestamp
- updated_at: timestamp

Indexes:
- unique index on token
- index on crew_id
- index on expires_at
- index on [crew_id, used_at] (for tracking active invitations)
```

#### unite_and_fights
```sql
- id: uuid (primary key)
- name: string (not null)
- event_number: integer (sequential, unique)
- starts_at: timestamp (not null)
- ends_at: timestamp (not null)
- created_by_id: uuid (foreign key to users, not null)
- created_at: timestamp
- updated_at: timestamp

Indexes:
- unique index on event_number
- index on starts_at
- index on ends_at
- index on [starts_at, ends_at] (for finding active events)
```

#### unf_scores
```sql
- id: uuid (primary key)
- unite_and_fight_id: uuid (foreign key to unite_and_fights, not null)
- crew_id: uuid (foreign key to crews, not null)
- user_id: uuid (foreign key to users, not null)
- honors: bigint (not null, default 0)
- recorded_by_id: uuid (foreign key to users, not null)
- day_number: integer (1-7, not null)
- created_at: timestamp
- updated_at: timestamp

Indexes:
- unique index on [unite_and_fight_id, crew_id, user_id, day_number]
- index on unite_and_fight_id
- index on crew_id
- index on user_id
- index on [crew_id, unite_and_fight_id] (for crew performance queries)
- index on honors (for rankings)
```

#### crew_feeds (future table for reference)
```sql
- id: uuid (primary key)
- crew_id: uuid (foreign key to crews, not null)
- feedable_type: string (Party, Guide, Post, etc.)
- feedable_id: uuid (polymorphic reference)
- created_at: timestamp

Indexes:
- index on [crew_id, created_at] (for feed queries)
- index on [feedable_type, feedable_id]
```

### Model Relationships

```ruby
# User model additions
has_one :crew_membership, dependent: :destroy
has_one :crew, through: :crew_membership
has_many :captained_crews, class_name: 'Crew', foreign_key: :captain_id
has_many :crew_invitations_sent, class_name: 'CrewInvitation', foreign_key: :invited_by_id
has_many :unf_scores
has_many :recorded_unf_scores, class_name: 'UnfScore', foreign_key: :recorded_by_id

# Crew model
belongs_to :captain, class_name: 'User'
has_many :crew_memberships, dependent: :destroy
has_many :members, through: :crew_memberships, source: :user
has_many :crew_invitations, dependent: :destroy
has_many :unf_scores, dependent: :destroy
has_many :subcaptains, -> { where(crew_memberships: { role: 1 }) },
         through: :crew_memberships, source: :user

# CrewMembership model
belongs_to :crew, counter_cache: :member_count
belongs_to :user
enum role: { member: 0, subcaptain: 1, captain: 2 }

# CrewInvitation model
belongs_to :crew
belongs_to :invited_by, class_name: 'User'
belongs_to :used_by, class_name: 'User', optional: true

# UniteAndFight model
has_many :unf_scores, dependent: :destroy
belongs_to :created_by, class_name: 'User'

# UnfScore model
belongs_to :unite_and_fight
belongs_to :crew
belongs_to :user
belongs_to :recorded_by, class_name: 'User'
```

### API Design

#### Crew Management

##### Crew CRUD
```
POST   /api/v1/crews
  Body: { name, rules?, gamertag? }
  Response: Created crew with captain membership

GET    /api/v1/crews/:id
  Response: Crew details with members list

PUT    /api/v1/crews/:id
  Body: { name?, rules?, gamertag? }
  Response: Updated crew (captain/subcaptain only)

DELETE /api/v1/crews/:id
  Response: Success (captain only, disbands crew)

GET    /api/v1/crews/my
  Response: Current user's crew with full details
```

##### Member Management
```
GET    /api/v1/crews/:id/members
  Response: Paginated list of crew members with roles

POST   /api/v1/crews/:id/members/promote
  Body: { user_id, role: "subcaptain" }
  Response: Updated membership (captain only)

DELETE /api/v1/crews/:id/members/:user_id
  Response: Success (captain only)

PUT    /api/v1/crews/:id/members/me
  Body: { display_gamertag }
  Response: Updated own membership settings
```

##### Invitations
```
POST   /api/v1/crews/:id/invitations
  Response: { invitation_url, token, expires_at }
  Note: Captain/subcaptain only

GET    /api/v1/crews/:id/invitations
  Response: List of pending invitations (captain/subcaptain)

DELETE /api/v1/crews/:id/invitations/:id
  Response: Revoke invitation (captain/subcaptain)

POST   /api/v1/crews/join
  Body: { token }
  Response: Joined crew details
```

#### Unite and Fight

##### Event Management (Admin)
```
GET    /api/v1/unite_and_fights
  Response: List of all UnF events

POST   /api/v1/unite_and_fights
  Body: { name, event_number, starts_at, ends_at }
  Response: Created event (requires level 7+ permissions)

PUT    /api/v1/unite_and_fights/:id
  Body: { name?, starts_at?, ends_at? }
  Response: Updated event (admin only)
```

##### Score Management
```
POST   /api/v1/unf_scores
  Body: { unite_and_fight_id, user_id, honors, day_number }
  Response: Created/updated score (captain/subcaptain only)

GET    /api/v1/crews/:crew_id/unf_scores
  Query: unite_and_fight_id?, user_id?
  Response: Scores for crew, optionally filtered

GET    /api/v1/unf_scores/performance
  Query: crew_id, user_id?, from_date?, to_date?
  Response: Performance data for graphing
```

#### Crew Feed
```
GET    /api/v1/crews/:id/feed
  Query: page, limit, type?
  Response: Paginated feed of crew-only content
```

### Authorization & Permissions

#### Permission Matrix

| Action | Captain | Subcaptain | Member | Non-member |
|--------|---------|------------|---------|------------|
| View crew info | ✓ | ✓ | ✓ | ✓ |
| View member list | ✓ | ✓ | ✓ | ✗ |
| Update crew info | ✓ | ✓ | ✗ | ✗ |
| Set gamertag | ✓ | ✓ | ✗ | ✗ |
| Invite members | ✓ | ✓ | ✗ | ✗ |
| Remove members | ✓ | ✗ | ✗ | ✗ |
| Promote to subcaptain | ✓ | ✗ | ✗ | ✗ |
| Record UnF scores | ✓ | ✓ | ✗ | ✗ |
| View UnF scores | ✓ | ✓ | ✓ | ✗ |
| View crew feed | ✓ | ✓ | ✓ | ✗ |
| Leave crew | ✗* | ✓ | ✓ | ✗ |

*Captain must transfer ownership or disband crew

#### Authorization Helpers

```ruby
# app/models/user.rb
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
```

### Security Considerations

1. **Invitation Security**:
   - Tokens are cryptographically secure random strings
   - Automatic expiration after 7 days
   - One-time use only
   - Rate limiting on join attempts

2. **Member Limits**:
   - Enforce 30 member maximum at database level
   - Check before invitation acceptance
   - Atomic operations for membership changes

3. **Role Management**:
   - Only captain can promote/demote
   - Maximum 3 subcaptains enforced
   - Captain role transfer requires explicit action

4. **Data Privacy**:
   - Crew-only content respects visibility settings
   - UnF scores only visible to crew members
   - Member list public, but details restricted

### Performance Considerations

1. **Caching**:
   - Cache crew member lists (5-minute TTL)
   - Cache UnF leaderboards (1-hour TTL)
   - Cache crew feed content

2. **Database Optimization**:
   - Counter cache for member_count
   - Composite indexes for common queries
   - Partial indexes for active records

3. **Query Optimization**:
   - Eager load associations
   - Pagination for member lists and feeds
   - Batch operations for UnF score updates

4. **Background Jobs**:
   - Async invitation email sending
   - Scheduled cleanup of expired invitations
   - UnF score aggregation calculations

## Implementation Phases

### Phase 1: Core Crew System (Week 1-2)
- Database migrations and models
- Basic CRUD operations
- Captain and member roles
- Invitation system

### Phase 2: Advanced Roles & Permissions (Week 3)
- Subcaptain functionality
- Permission system
- Gamertag management
- Crew rules

### Phase 3: Unite and Fight Integration (Week 4-5)
- UnF event management
- Score recording system
- Performance queries
- Basic reporting

### Phase 4: Feed & Analytics (Week 6)
- Crew feed implementation
- Integration with parties/guides
- Performance graphs
- Historical tracking

### Phase 5: Polish & Optimization (Week 7)
- Performance tuning
- Caching layer
- Background jobs
- Admin tools

## Success Metrics

1. **Adoption**: 60% of active users join a crew within 3 months
2. **Engagement**: Average crew has 15+ active members
3. **Performance**: All crew operations complete within 200ms
4. **Reliability**: 99.9% uptime for crew services
5. **UnF Participation**: 80% score recording during events

## Future Enhancements

1. **Crew Battles**: Inter-crew competitions outside UnF
2. **Crew Chat**: Real-time messaging system
3. **Crew Achievements**: Badges and milestones
4. **Crew Resources**: Shared guides and strategies library
5. **Crew Recruitment**: Public crew discovery and application system
6. **Officer Roles**: Additional permission tiers
7. **Crew Alliances**: Multi-crew coordination
8. **Automated Scoring**: API integration with game data (if available)
9. **Mobile Notifications**: Push notifications for crew events
10. **Crew Statistics**: Advanced analytics and insights

## Risk Mitigation

1. **Toxic Behavior**: Implement reporting system and moderation tools
2. **Inactive Crews**: Automatic leadership transfer after inactivity
3. **Database Load**: Implement read replicas for heavy queries
4. **Invitation Spam**: Rate limiting and abuse detection
5. **Score Manipulation**: Audit logs and validation rules