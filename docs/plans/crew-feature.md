# Crew Feature Implementation Plan

## Overview

Implement a comprehensive Crew system for Granblue Fantasy team management, including crew formation, role management, invitations, Unite and Fight (GW) event tracking with individual and crew-wide scoring, and interactive visualizations.

## Workflow

- Commit often in logical groups
- Track commit hashes next to completed tasks: `[abc1234]`
- Terse, informal commit messages

---

## Phase 1: Core Crew Infrastructure

### Database Migrations

- [x] **1. `create_crews`** `[9b01aa0]`
```
crews:
  - id: uuid (PK)
  - name: string (required, max 100)
  - gamertag: string (text-only tag for profiles)
  - granblue_crew_id: string (in-game ID, unique)
  - description: text
  - timestamps
```

- [x] **2. `create_crew_memberships`** `[9b01aa0]`
```
crew_memberships:
  - id: uuid (PK)
  - crew_id: uuid (FK, required)
  - user_id: uuid (FK, required)
  - role: integer (0=member, 1=vice_captain, 2=captain)
  - retired: boolean (default: false)
  - retired_at: datetime
  - timestamps

Indices:
  - unique on [crew_id, user_id]
  - partial unique on [user_id] WHERE retired=false (one active crew per user)
```

- [x] **3. `add_show_gamertag_to_users`** `[9b01aa0]`
```
Add: show_gamertag: boolean (default: true)
```

### Backend Files to Create

| Status | File | Purpose |
|:------:|------|---------|
| [x] `[9b01aa0]` | `app/models/crew.rb` | Crew model with associations, validations |
| [x] `[9b01aa0]` | `app/models/crew_membership.rb` | Membership with role enum, retirement logic |
| [x] `[e98e594]` | `app/controllers/api/v1/crews_controller.rb` | CRUD, leave, transfer captain |
| [x] `[e98e594]` | `app/controllers/api/v1/crew_memberships_controller.rb` | Promote, demote, remove |
| [x] `[e98e594]` | `app/controllers/concerns/crew_authorization_concern.rb` | Officer/captain checks |
| [x] `[e98e594]` | `app/blueprints/api/v1/crew_blueprint.rb` | Crew serialization |
| [x] `[e98e594]` | `app/blueprints/api/v1/crew_membership_blueprint.rb` | Membership serialization |
| [x] `[872b6fd]` | `app/errors/crew_errors.rb` | Custom errors (restructured for Zeitwerk) |

### Backend Files to Modify

| Status | File | Changes |
|:------:|------|---------|
| [x] `[9b01aa0]` | `app/models/user.rb` | Add crew associations, implement `in_same_crew_as?` |
| [x] `[9b01aa0]` | `app/models/user.rb` | Update `collection_viewable_by?` for crew_only |
| [ ] | `app/blueprints/api/v1/user_blueprint.rb` | Add gamertag and crew info to minimal view |
| [x] `[e98e594]` | `config/routes.rb` | Add crew routes |

### Backend Tests

| Status | File | Purpose |
|:------:|------|---------|
| [x] `[872b6fd]` | `spec/models/crew_spec.rb` | Crew model specs (18 examples) |
| [x] `[872b6fd]` | `spec/models/crew_membership_spec.rb` | CrewMembership model specs (16 examples) |
| [x] `[872b6fd]` | `spec/models/user_spec.rb` | User crew association specs (22 examples) |
| [x] `[872b6fd]` | `spec/requests/crews_controller_spec.rb` | Crews API specs (15 examples) |
| [x] `[872b6fd]` | `spec/requests/crew_memberships_controller_spec.rb` | Memberships API specs (13 examples) |
| [x] `[872b6fd]` | `spec/factories/crews.rb` | Crew factory |
| [x] `[872b6fd]` | `spec/factories/crew_memberships.rb` | CrewMembership factory |

### API Endpoints

```
POST   /crews                    - Create crew (user becomes captain)
GET    /crew                     - Current user's crew
PUT    /crew                     - Update crew (officers only)
GET    /crew/members             - List members
POST   /crew/leave               - Leave crew (not captain)
POST   /crews/:id/transfer_captain - Transfer ownership
PUT    /crews/:id/memberships/:id  - Update member role
DELETE /crews/:id/memberships/:id  - Remove member
```

### Frontend (hensei-web)

**Pages:**
- [ ] `/crew` - Dashboard (redirect to create if no crew)
- [ ] `/crew/create` - Create crew form
- [ ] `/crew/settings` - Crew settings (officers)
- [ ] `/crew/members` - Member management

**Components:**
- [ ] `components/crew/CrewDashboard/`
- [ ] `components/crew/CrewHeader/`
- [ ] `components/crew/CrewMemberList/`
- [ ] `components/crew/CreateCrewForm/`

---

## Phase 2: Invitations System

### Database Migration

- [x] **`create_crew_invitations`** `[b75a905]`
```
crew_invitations:
  - id: uuid (PK)
  - crew_id: uuid (FK, required)
  - user_id: uuid (FK, required - invitee)
  - invited_by_id: uuid (FK, required)
  - status: integer (0=pending, 1=accepted, 2=rejected, 3=expired)
  - expires_at: datetime
  - timestamps

Indices:
  - on [crew_id, user_id, status]
  - on [user_id, status]
```

### Backend Files to Create

| Status | File | Purpose |
|:------:|------|---------|
| [x] `[b75a905]` | `app/models/crew_invitation.rb` | Invitation model with accept/reject |
| [x] `[b75a905]` | `app/controllers/api/v1/crew_invitations_controller.rb` | Send, list, accept, reject |
| [x] `[b75a905]` | `app/blueprints/api/v1/crew_invitation_blueprint.rb` | Invitation serialization |
| [x] `[b75a905]` | `app/errors/crew_errors.rb` | Added invitation error classes |

### Backend Tests

| Status | File | Purpose |
|:------:|------|---------|
| [x] `[b75a905]` | `spec/models/crew_invitation_spec.rb` | CrewInvitation model specs (21 examples) |
| [x] `[b75a905]` | `spec/requests/crew_invitations_controller_spec.rb` | Invitations API specs (17 examples) |
| [x] `[b75a905]` | `spec/factories/crew_invitations.rb` | CrewInvitation factory |

### API Endpoints

```
POST   /crews/:id/invitations    - Send invitation (officers)
GET    /crews/:id/invitations    - List crew's invitations
GET    /invitations/pending      - User's pending invitations
POST   /invitations/:id/accept   - Accept invitation
POST   /invitations/:id/reject   - Reject invitation
```

### Frontend

**Pages:**
- [ ] `/crew/join` - View and respond to invitations

**Components:**
- [ ] `components/crew/CrewInvitationBanner/` - Top-of-page banner in Header
- [ ] `components/crew/JoinCrewSection/` - Invitation list with accept/reject

**Modify:**
- [ ] `components/Header/` - Add invitation banner for pending invites

---

## Phase 3: GW Events & Basic Scoring

### Database Migrations

- [ ] **1. `create_gw_events`** (admin-managed via Database CMS)
```
gw_events:
  - id: uuid (PK)
  - name: string (required)
  - element: integer (required, uses GranblueEnums::ELEMENTS)
  - start_date: date (required)
  - end_date: date (required)
  - event_number: integer (GW #XX, unique)
  - timestamps
```

- [ ] **2. `create_crew_gw_participations`**
```
crew_gw_participations:
  - id: uuid (PK)
  - crew_id: uuid (FK)
  - gw_event_id: uuid (FK)
  - preliminary_ranking: bigint
  - final_ranking: bigint
  - timestamps

Unique: [crew_id, gw_event_id]
```

- [ ] **3. `create_gw_crew_scores`** (crew-wide round scores)
```
gw_crew_scores:
  - id: uuid (PK)
  - crew_gw_participation_id: uuid (FK)
  - round: integer (0=prelims, 1=interlude, 2-5=finals day 1-4)
  - crew_score: bigint
  - opponent_score: bigint
  - opponent_name: string
  - opponent_granblue_id: string
  - victory: boolean
  - timestamps

Unique: [crew_gw_participation_id, round]
```

- [ ] **4. `create_gw_individual_scores`**
```
gw_individual_scores:
  - id: uuid (PK)
  - crew_gw_participation_id: uuid (FK)
  - crew_membership_id: uuid (FK, nullable)
  - phantom_player_id: uuid (FK, nullable)
  - round: integer
  - score: bigint (default: 0)
  - is_cumulative: boolean (default: false)
  - recorded_by_id: uuid (FK)
  - timestamps

Constraints: Exactly one of crew_membership_id or phantom_player_id must be set
```

### Backend Files to Create

| Status | File | Purpose |
|:------:|------|---------|
| [ ] | `app/models/gw_event.rb` | Event model with element, dates |
| [ ] | `app/models/crew_gw_participation.rb` | Links crew to event |
| [ ] | `app/models/gw_crew_score.rb` | Crew-level round scores |
| [ ] | `app/models/gw_individual_score.rb` | Individual scores with permission checks |
| [ ] | `app/controllers/api/v1/gw_events_controller.rb` | CRUD (admin create/update) |
| [ ] | `app/controllers/api/v1/crew_gw_participations_controller.rb` | Join event, get participation |
| [ ] | `app/controllers/api/v1/gw_crew_scores_controller.rb` | Crew score entry |
| [ ] | `app/controllers/api/v1/gw_individual_scores_controller.rb` | Individual + batch entry |
| [ ] | `app/blueprints/api/v1/gw_*_blueprint.rb` | Serializers for all GW models |

### API Endpoints

```
# GW Events (admin creates via CMS)
GET    /gw_events                - List all events
GET    /gw_events/:id            - Show event
POST   /gw_events                - Create event (admin)
PUT    /gw_events/:id            - Update event (admin)

# Participations
POST   /gw_events/:id/participations       - Join event
GET    /crew/gw_participations             - Crew's participations
GET    /crew/gw_participations/:id         - Single participation with scores

# Scores
POST   /gw_events/:eid/participations/:pid/crew_scores      - Add crew score
PUT    /gw_events/:eid/participations/:pid/crew_scores/:id  - Update crew score
POST   /gw_events/:eid/participations/:pid/individual_scores      - Add individual
POST   /gw_events/:eid/participations/:pid/individual_scores/batch - Batch entry
```

### Frontend

**Pages:**
- [ ] `/crew/gw` - GW overview (list of events)
- [ ] `/crew/gw/[eventId]` - Event detail with scores
- [ ] `/crew/gw/[eventId]/scores` - Score entry interface

**Components:**
- [ ] `components/gw/GwEventCard/`
- [ ] `components/gw/GwScoreBoard/`
- [ ] `components/gw/GwCrewScoreForm/`
- [ ] `components/gw/GwIndividualScoreForm/`

---

## Phase 4: Phantom Players & Retired Members

### Database Migration

- [ ] **`create_phantom_players`**
```
phantom_players:
  - id: uuid (PK)
  - crew_id: uuid (FK)
  - name: string (required)
  - granblue_id: string
  - notes: text
  - claimed_by_id: uuid (FK to users, nullable)
  - claimed_from_membership_id: uuid (FK, nullable)
  - claim_confirmed: boolean (default: false)
  - timestamps

Unique: [crew_id, granblue_id] WHERE granblue_id IS NOT NULL
```

### Backend Files to Create

| Status | File | Purpose |
|:------:|------|---------|
| [ ] | `app/models/phantom_player.rb` | Phantom with claim flow |
| [ ] | `app/controllers/api/v1/phantom_players_controller.rb` | CRUD, assign, confirm |

### Claim Flow

1. Captain creates phantom player (name, granblue_id, notes)
2. Real user joins crew
3. Captain assigns phantom to user (`claimed_by_id` set)
4. User confirms claim (`claim_confirmed` = true)
5. All phantom scores transfer to user's membership

### Retirement Flow

1. Member leaves or is removed
2. `CrewMembership.retired` = true, `retired_at` = now
3. Historical scores remain linked to membership
4. No new scores can be added to retired members
5. Scores visible to current crew members

### API Endpoints

```
GET    /crews/:id/phantom_players     - List phantoms
POST   /crews/:id/phantom_players     - Create phantom
PUT    /crews/:id/phantom_players/:id - Update phantom
DELETE /crews/:id/phantom_players/:id - Delete phantom
POST   /crews/:id/phantom_players/:id/assign        - Assign to user
POST   /crews/:id/phantom_players/:id/confirm_claim - User confirms
```

### Frontend

**Components:**
- [ ] `components/phantom/PhantomPlayerList/`
- [ ] `components/phantom/PhantomPlayerForm/`
- [ ] `components/phantom/PhantomClaimDialog/`

---

## Phase 5: Batch Score Entry & Visualization

### Backend

- [ ] **Batch Endpoint Enhancement:**
```
POST /gw_events/:eid/participations/:pid/individual_scores/batch
Body: { scores: [{ player_id, player_type, round, score }, ...] }
```

- [ ] **Aggregation Endpoints:**
```
GET /crew/gw_participations/:id/leaderboard   - Player rankings
GET /crew/gw_participations/:id/chart_data    - Time series for charts
```

### Frontend - Batch Entry

- [ ] **Component:** `components/gw/GwBatchScoreEntry/`
  - Spreadsheet-style grid (players as rows, rounds as columns)
  - Tab/Enter navigation
  - Paste from spreadsheet support
  - Toggle between individual and batch modes

### Frontend - Visualization (Apache ECharts)

**Install:** `npm install echarts echarts-for-react`

**Components:**
- [ ] `components/gw/GwScoreChart/` - Main interactive chart
- [ ] `components/gw/GwPlayerRanking/` - Sortable player leaderboard
- [ ] `components/gw/GwProgressChart/` - Progress over time

**Chart Features:**
- Individual focus: Player rankings, personal progress, personal bests
- Time axis control: Filter by event date range
- Player selection: Toggle which players are visible
- Event filter: Compare across multiple GW events

---

## Phase 6: Profile Integration & Polish

### Backend

- [ ] **Update UserBlueprint** (`app/blueprints/api/v1/user_blueprint.rb`):
```ruby
view :minimal do
  # ... existing fields ...

  field :gamertag, if: ->(_, user, _) {
    user.show_gamertag && user.crew&.gamertag.present?
  } do |user|
    user.crew&.gamertag
  end
end
```

### Frontend

**User Settings:**
- [ ] Add toggle: "Show crew gamertag on profile"
- [ ] Located in existing settings page

**Profile Display:**
- [ ] Show gamertag badge next to username when enabled
- [ ] Format: `[CREW] Username` or similar styling

**Admin Pages:**
- [ ] `/admin/gw-events` - GW event management for Database CMS

---

## Authorization Matrix

| Action | Captain | Vice Captain | Member | Non-member |
|--------|:-------:|:------------:|:------:|:----------:|
| View crew dashboard | Yes | Yes | Yes | No |
| Edit crew info | Yes | Yes | No | No |
| Send invitations | Yes | Yes | No | No |
| Promote to VC | Yes | No | No | No |
| Demote VC | Yes | No | No | No |
| Remove member | Yes | Yes | No | No |
| Transfer captain | Yes | No | No | No |
| Record own score | Yes | Yes | Yes | No |
| Record others' scores | Yes | Yes | No | No |
| Manage phantoms | Yes | Yes | No | No |
| View GW history | Yes | Yes | Yes | No |

---

## Key Files Reference

### Backend - To Create
```
app/models/
  crew.rb
  crew_membership.rb
  crew_invitation.rb
  phantom_player.rb
  gw_event.rb
  crew_gw_participation.rb
  gw_crew_score.rb
  gw_individual_score.rb

app/controllers/api/v1/
  crews_controller.rb
  crew_memberships_controller.rb
  crew_invitations_controller.rb
  phantom_players_controller.rb
  gw_events_controller.rb
  crew_gw_participations_controller.rb
  gw_crew_scores_controller.rb
  gw_individual_scores_controller.rb

app/blueprints/api/v1/
  crew_blueprint.rb
  crew_membership_blueprint.rb
  crew_invitation_blueprint.rb
  phantom_player_blueprint.rb
  gw_event_blueprint.rb
  crew_gw_participation_blueprint.rb
  gw_crew_score_blueprint.rb
  gw_individual_score_blueprint.rb

app/controllers/concerns/
  crew_authorization_concern.rb

app/errors/
  crew_errors.rb
```

### Backend - To Modify
```
app/models/user.rb                           # Add crew associations
app/blueprints/api/v1/user_blueprint.rb      # Add gamertag
config/routes.rb                              # Add all crew routes
```

### Frontend - To Create
```
app/[locale]/crew/
  page.tsx
  create/page.tsx
  settings/page.tsx
  members/page.tsx
  join/page.tsx
  gw/
    page.tsx
    [eventId]/
      page.tsx
      scores/page.tsx

components/
  crew/
    CrewDashboard/
    CrewHeader/
    CrewMemberList/
    CrewInvitationBanner/
    CreateCrewForm/
    JoinCrewSection/
  gw/
    GwEventCard/
    GwScoreBoard/
    GwCrewScoreForm/
    GwIndividualScoreForm/
    GwBatchScoreEntry/
    GwScoreChart/
    GwPlayerRanking/
    GwProgressChart/
  phantom/
    PhantomPlayerList/
    PhantomPlayerForm/
    PhantomClaimDialog/

stores/
  crewStore.ts
  gwStore.ts
```

### Frontend - To Modify
```
components/Header/index.tsx                  # Add invitation banner
app/[locale]/settings/                       # Add gamertag toggle
```

---

## Implementation Order

1. **Phase 1** - Core crew (can deploy independently)
2. **Phase 2** - Invitations (enables recruiting)
3. **Phase 3** - GW events & scoring (core value feature)
4. **Phase 4** - Phantom players (completes scoring for non-users)
5. **Phase 5** - Batch entry & visualization (polish & UX)
6. **Phase 6** - Profile integration (final touches)

Each phase is deployable independently after Phase 1.
