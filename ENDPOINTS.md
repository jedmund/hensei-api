# Hensei API Documentation

## Authentication

All API endpoints require authentication using OAuth2 via Doorkeeper. You must include a valid access token in the Authorization header:

```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

## Endpoints

### Authentication Endpoints

#### Token Generation
- **POST** `/oauth/token`
  - Generate access token for user authentication

### User Endpoints

#### Create User
- **POST** `/api/v1/users`
  - Create a new user account

#### Update User
- **PUT** `/api/v1/users/:id`
  - Update user information

#### Get User Info
- **GET** `/api/v1/users/info/:id`
  - Retrieve user information

#### Email & Username Availability Check
- **POST** `/api/v1/check/email`
  - Check if email is available for registration
- **POST** `/api/v1/check/username`
  - Check if username is available

### Party Endpoints

#### List Parties
- **GET** `/api/v1/parties`
  - Retrieve list of parties

#### Create Party
- **POST** `/api/v1/parties`
  - Create a new party

#### Update Party
- **PUT** `/api/v1/parties/:id`
  - Update an existing party

#### Delete Party
- **DELETE** `/api/v1/parties/:id`
  - Delete a party

#### Get Party Details
- **GET** `/api/v1/parties/:id`
  - Retrieve detailed information about a specific party

#### Remix Party
- **POST** `/api/v1/parties/:id/remix`
  - Create a remix (copy) of an existing party

#### Favorites
- **GET** `/api/v1/parties/favorites`
  - Retrieve user's favorite parties
- **POST** `/api/v1/favorites`
  - Add a party to favorites
- **DELETE** `/api/v1/favorites`
  - Remove a party from favorites

### Job Management

#### Update Job
- **PUT** `/api/v1/parties/:id/jobs`
  - Update job for a party

#### Update Job Skills
- **PUT** `/api/v1/parties/:id/job_skills`
  - Update job skills for a party
- **DELETE** `/api/v1/parties/:id/job_skills`
  - Remove a job skill from a party

#### Job Endpoints
- **GET** `/api/v1/jobs`
  - List all jobs
- **GET** `/api/v1/jobs/:id`
  - Get details of a specific job
- **GET** `/api/v1/jobs/:id/skills`
  - Get skills for a specific job
- **GET** `/api/v1/jobs/:id/accessories`
  - Get accessories for a specific job

### Grid Management

#### Characters
- **POST** `/api/v1/characters`
  - Add a character to a party
- **POST** `/api/v1/characters/resolve`
  - Resolve character conflicts
- **POST** `/api/v1/characters/update_uncap`
  - Update character uncap level
- **DELETE** `/api/v1/characters`
  - Remove a character from a party

#### Weapons
- **POST** `/api/v1/weapons`
  - Add a weapon to a party
- **POST** `/api/v1/weapons/resolve`
  - Resolve weapon conflicts
- **POST** `/api/v1/weapons/update_uncap`
  - Update weapon uncap level
- **DELETE** `/api/v1/weapons`
  - Remove a weapon from a party

#### Summons
- **POST** `/api/v1/summons`
  - Add a summon to a party
- **POST** `/api/v1/summons/update_uncap`
  - Update summon uncap level
- **POST** `/api/v1/summons/update_quick_summon`
  - Update quick summon status
- **DELETE** `/api/v1/summons`
  - Remove a summon from a party

### Search Endpoints

#### Global Search
- **POST** `/api/v1/search`
  - Perform a global search across all object types

#### Specific Object Searches
- **POST** `/api/v1/search/characters`
  - Search characters
- **POST** `/api/v1/search/weapons`
  - Search weapons
- **POST** `/api/v1/search/summons`
  - Search summons
- **POST** `/api/v1/search/job_skills`
  - Search job skills
- **POST** `/api/v1/search/guidebooks`
  - Search guidebooks

### Reference Endpoints

#### Guidebooks
- **GET** `/api/v1/guidebooks`
  - List all guidebooks

#### Raids
- **GET** `/api/v1/raids`
  - List all raids
- **GET** `/api/v1/raids/groups`
  - List raid groups
- **GET** `/api/v1/raids/:id`
  - Get details of a specific raid

#### Weapon Keys
- **GET** `/api/v1/weapon_keys`
  - List all weapon keys

### Object Detail Endpoints

#### Get Object Details
- **GET** `/api/v1/weapons/:granblue_id`
  - Get weapon details
- **GET** `/api/v1/characters/:granblue_id`
  - Get character details
- **GET** `/api/v1/summons/:granblue_id`
  - Get summon details

### Utility Endpoints

#### Version
- **GET** `/api/v1/version`
  - Get current API version

#### Import
- **POST** `/api/v1/import`
  - Import party data from game

## Request and Response Formats

- All endpoints return JSON
- Requests should include the `Content-Type: application/json` header
- Authentication is required via Bearer token

## Error Handling

- Successful requests return HTTP 200 (OK) or 201 (Created)
- Failed requests return appropriate HTTP status codes with error details in the response body

## Rate Limiting

[Specify your rate limiting policy]

## Pagination

[Specify your pagination approach for list endpoints]

## Notes

- All endpoints are versioned under `/api/v1/`
- Timestamps are typically returned in ISO 8601 format
- Dates are typically returned in YYYY-MM-DD format
