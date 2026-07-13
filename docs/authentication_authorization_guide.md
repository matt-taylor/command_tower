# CommandTower Authentication & Authorization Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Authentication System](#authentication-system)
   - [2.1 Overview](#21-overview)
   - [2.2 Token Generation](#22-token-generation)
   - [2.3 Token Requirements](#23-token-requirements)
   - [2.4 Token Validation](#24-token-validation)
   - [2.5 Token Expiration](#25-token-expiration)
   - [2.6 Token Refresh](#26-token-refresh)
   - [2.7 Token Invalidation](#27-token-invalidation)
3. [Authorization System (RBAC)](#authorization-system-rbac)
   - [3.1 Overview](#31-overview)
   - [3.2 Core Concepts](#32-core-concepts)
   - [3.3 Authorization Requirements](#33-authorization-requirements)
   - [3.4 Role Definitions](#34-role-definitions)
   - [3.5 Entity Definitions](#35-entity-definitions)
   - [3.6 Authorization Validation Process](#36-authorization-validation-process)
   - [3.7 Authorization Failure (403 Forbidden)](#37-authorization-failure-403-forbidden)
4. [Integration Guide](#integration-guide)
   - [4.1 Setting Up Authentication](#41-setting-up-authentication)
   - [4.2 Setting Up Authorization](#42-setting-up-authorization)
   - [4.3 Client Implementation](#43-client-implementation)
5. [Configuration](#configuration)
   - [5.1 JWT Configuration](#51-jwt-configuration)
   - [5.2 Authorization Configuration](#52-authorization-configuration)
6. [Security Considerations](#security-considerations)
7. [Troubleshooting](#troubleshooting)
8. [Examples and Use Cases](#examples-and-use-cases)
9. [API Reference](#api-reference)

---

## Introduction

### Overview of CommandTower Authentication & Authorization

CommandTower provides a comprehensive authentication and authorization system built on JWT (JSON Web Tokens) and RBAC (Role-Based Access Control). This guide explains how these systems work together to secure your API endpoints.

**Authentication** answers the question: "Who are you?" It verifies the identity of the user making the request using JWT tokens.

**Authorization** answers the question: "What are you allowed to do?" It verifies that the authenticated user has the necessary permissions (roles) to perform the requested action.

### Relationship between Authentication and Authorization

Authentication must occur **before** authorization. The flow is:

1. **Authentication** (`authenticate_user!`): Validates the JWT token and sets `current_user`
2. **Authorization** (`authorize_user!`): Checks if `current_user` has the required role(s) for the action

If authentication fails, a `401 Unauthorized` is returned. If authorization fails, a `403 Forbidden` is returned.

### HTTP Status Codes: 401 vs 403

- **401 Unauthorized**: Authentication failure
  - Missing or invalid token
  - Expired token
  - Invalid verifier token
  - User not found

- **403 Forbidden**: Authorization failure
  - User is authenticated but lacks required role(s)
  - User's roles don't match the required permissions for the controller/action

---

## Authentication System

### 2.1 Overview

CommandTower uses **JWT (JSON Web Tokens)** for authentication. JWT tokens are stateless, encrypted tokens that contain user identity information.

#### Token Structure

JWT tokens contain the following encrypted payload:

```json
{
  "user_id": 123,
  "verifier_token": "abc123xyz",
  "generated_at": 1705440000
}
```

- **`user_id`** (Integer): The authenticated user's ID
- **`verifier_token`** (String): A token that must match the user's current verifier_token in the database
- **`generated_at`** (Integer): Unix timestamp when the token was created

#### Encryption

JWT tokens are encrypted using the **HS256 algorithm** with a secret key configured via:
- `CommandTower.config.jwt.hmac_secret` (defaults to `ENV['SECRET_KEY_BASE']`)

The secret key is used to both sign and verify tokens, ensuring they cannot be tampered with.

### 2.2 Token Generation

#### Initial Token Generation via Login

Tokens are generated when a user successfully logs in through the authentication endpoints.

**Endpoint**: `POST /auth/login`

**Request Headers**:
```
Content-Type: application/json
```

**Request Body**:
```json
{
  "identifier": "johndoe",
  "password": "securepassword123"
}
```

**Field Requirements**:
- `identifier` must be provided (can be username or email)
- `password` is required
- The system will check both username and email fields to find the user

**Response** (201 Created):
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxMjMsInZlcmlmaWVyX3Rva2VuIjoiYWJjMTIzIiwiZ2VuZXJhdGVkX2F0IjoxNzA1NDQwMDAwfQ.signature",
  "header_name": "Authorization",
  "message": "Successfully logged user in",
  "user": {
    "id": 123,
    "username": "johndoe",
    "email": "john@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "email_validated": true,
    "roles": ["user"],
    "created_at": "2024-01-15T10:00:00Z",
    "verifier_token": "abc123xyz",
    "last_known_timezone": "America/New_York"
  }
}
```

**Response Schema**:
- `token` (String, required): JWT token to use in Authorization header for subsequent requests
- `header_name` (String, required): Always "Authorization"
- `message` (String, required): Success message
- `user` (Object, required): User object with configured default attributes

**Error Responses**:
- `400 Bad Request`: Invalid request format
- `401 Unauthorized`: Invalid credentials or invalid arguments

**Example Error Response** (401):
```json
{
  "status": "401",
  "message": "Unauthorized Access. Incorrect Credentials",
  "invalid_arguments": {
    "identifier": ["Unauthorized Access. Incorrect Credentials"],
    "password": ["Parameter [password] is required but not present"]
  }
}
```

#### Token Generation Process

When a user logs in successfully:

1. **User Lookup**: System finds user by username or email
2. **Password Verification**: Password is verified against stored hash
3. **Verifier Token Retrieval**: System retrieves or generates `verifier_token` for the user
4. **Token Creation**: `CommandTower::Jwt::LoginCreate` service creates JWT token with:
   - `user_id`: User's database ID
   - `verifier_token`: User's current verifier_token
   - `generated_at`: Current Unix timestamp
5. **Token Encoding**: Token is encoded using HS256 algorithm with HMAC secret
6. **Response**: Token is returned to client in response body

**Code Flow**:
```ruby
# In CommandTower::Jwt::LoginCreate
payload = {
  generated_at: Time.now.to_i,
  user_id: user.id,
  verifier_token: user.retreive_verifier_token!,
}
token = JWT.encode(payload, CommandTower.config.jwt.hmac_secret, "HS256")
```

### 2.3 Token Requirements

#### When Tokens Are Required

Tokens are required for any endpoint that uses the `before_action :authenticate_user!` callback. This includes:

- User management endpoints (`/user/*`)
- Admin endpoints (`/admin/*`)
- Inbox endpoints (`/inbox/*`)
- Any custom endpoints that include authentication

#### Header Format

**Required Header**:
```
Authorization: Bearer {token_value}
```

**Critical Format Requirements**:
- The header value MUST be in the format: `Bearer {token}` (with a space between "Bearer" and the token)
- The word "Bearer" is case-sensitive
- Missing or malformed headers will result in `401 Unauthorized` responses

**Example**:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxMjMsInZlcmlmaWVyX3Rva2VuIjoiYWJjMTIzIiwiZ2VuZXJhdGVkX2F0IjoxNzA1NDQwMDAwfQ.signature
```

#### Controller Setup

To require authentication on a controller:

```ruby
class MyController < CommandTower::ApplicationController
  before_action :authenticate_user!

  def my_action
    # current_user is available here
  end
end
```

### 2.4 Token Validation

#### Validation Process

When a request includes an `Authorization` header, the following validation occurs:

1. **Header Extraction**: System extracts token from `Authorization: Bearer {token}` header
2. **Token Decoding**: `CommandTower::Jwt::Decode` service decodes the token using HMAC secret
3. **Payload Extraction**: Extracts `user_id`, `verifier_token`, and `generated_at` from payload
4. **User Lookup**: Finds user by `user_id` from the database
5. **Verifier Token Match**: Compares token's `verifier_token` with user's current `verifier_token`
6. **Expiration Check**: Validates that token hasn't expired
7. **Email Validation** (if enabled): Checks if user's email is validated

#### Validation Failure Scenarios

**1. Missing Authorization Header**

**Request**:
```
GET /user/
(no Authorization header)
```

**Response** (401 Unauthorized):
```json
{
  "status": "401",
  "message": "Bearer token missing"
}
```

**2. Invalid Bearer Token Format**

**Request**:
```
GET /user/
Authorization: InvalidFormat token123
```

**Response** (401 Unauthorized):
```json
{
  "status": "401",
  "message": "Invalid Bearer token format"
}
```

**3. Expired Token**

**Request**:
```
GET /user/
Authorization: Bearer {expired_token}
```

**Response** (401 Unauthorized):
```json
{
  "status": "401",
  "message": "Unauthorized Access. Invalid Authorization token"
}
```

**4. Invalid Verifier Token**

When a user's `verifier_token` is reset (e.g., logout all sessions), all existing tokens become invalid.

**Request**:
```
GET /user/
Authorization: Bearer {token_with_old_verifier_token}
```

**Response** (401 Unauthorized):
```json
{
  "status": "401",
  "message": "Unauthorized Access. Token is no longer valid"
}
```

**5. User Not Found**

If the `user_id` in the token doesn't exist in the database:

**Response** (401 Unauthorized):
```json
{
  "status": "401",
  "message": "Unauthorized Access. Invalid Authorization token"
}
```

**6. Email Not Validated** (when email verification is enabled)

**Response** (412 Precondition Failed):
```json
{
  "status": "412",
  "message": "Email must be verified to continue",
  "meta": {
    "email_validated": false
  }
}
```

#### Validation Code Flow

```ruby
# In CommandTower::Jwt::AuthenticateUser
def call
  # 1. Decode token
  result = Decode.(token:)
  return context.fail! if result.failure?

  payload = result.payload

  # 2. Validate expiration
  expires_at = validate_generated_at!(generated_at: payload[:generated_at])

  # 3. Find user
  user = User.find(payload[:user_id])
  return context.fail! if user.nil?

  # 4. Verify verifier_token matches
  if user.verifier_token == payload[:verifier_token]
    context.user = user
  else
    context.fail!(msg: "Unauthorized Access. Token is no longer valid")
  end

  # 5. Check email validation (if enabled)
  email_validation_required!(user:)

  context.expires_at = expires_at.to_s
end
```

### 2.5 Token Expiration

#### How Expiration Works

Token expiration is calculated based on:

1. **`generated_at`**: Unix timestamp when token was created (stored in token payload)
2. **TTL (Time To Live)**: Configured duration (default: 7 days)

**Expiration Time** = `generated_at` + `CommandTower.config.jwt.ttl`

#### Expiration Header

Every authenticated request returns a header indicating when the current token will expire:

**Response Header**:
```
X-Authorization-Expire: "2025-01-16 04:36:29 +0000"
```

**Format**: ISO 8601 timestamp string

#### When Tokens Expire

Tokens expire when:
- Current time >= `generated_at` + TTL
- After expiration, the token is no longer valid
- All requests with expired tokens return `401 Unauthorized`

**Example**:
- Token created: `2025-01-09 04:36:29 +0000`
- TTL: `7.days`
- Expires: `2025-01-16 04:36:29 +0000`
- After `2025-01-16 04:36:29 +0000`, token is invalid

#### Client Monitoring Strategies

**Recommended Approach**:

1. **Parse Expiration Header**: Extract `X-Authorization-Expire` from every authenticated response
2. **Calculate Time Remaining**: Calculate time until expiration
3. **Refresh Before Expiration**: Refresh token when less than 5 minutes remain
4. **Handle Expiration Gracefully**: If token expires, redirect to login

**Example Client Implementation** (pseudo-code):
```javascript
function checkTokenExpiration(response) {
  const expireHeader = response.headers['X-Authorization-Expire'];
  if (!expireHeader) return;

  const expirationTime = new Date(expireHeader);
  const now = new Date();
  const timeRemaining = expirationTime - now;
  const fiveMinutes = 5 * 60 * 1000;

  if (timeRemaining < fiveMinutes) {
    refreshToken();
  }
}
```

### 2.6 Token Refresh

#### When to Refresh Tokens

Tokens should be refreshed:
- **Before expiration**: When less than 5 minutes remain before expiration
- **After password change**: To ensure old tokens are invalidated
- **Periodically**: As a proactive measure (e.g., every 24 hours)
- **After role changes**: To ensure new permissions are reflected

**Best Practice**: Refresh tokens proactively before expiration rather than reactively after expiration.

#### How to Request Token Refresh

Token refresh can be requested on **any authenticated endpoint** by including a special header.

**Request Header**:
```
X-Authorization-Reset: true
```

**Note**: The value can be `true`, `"true"`, `1`, or `"1"` (boolean values are accepted in multiple formats).

#### Token Refresh Process

1. **Client Request**: Include `X-Authorization-Reset: true` header in any authenticated request
2. **Server Validation**: Server validates the existing token (normal authentication flow)
3. **Token Generation**: If validation succeeds, server generates a new token with:
   - Same `user_id`
   - Current `verifier_token`
   - New `generated_at` (current timestamp)
4. **Response Header**: New token is returned in `X-Authorization-Reset` header
5. **Expiration Update**: New expiration time is returned in `X-Authorization-Expire` header

#### Complete Token Refresh Example

**Request**:
```
POST /user/modify
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxMjMsInZlcmlmaWVyX3Rva2VuIjoiYWJjMTIzIiwiZ2VuZXJhdGVkX2F0IjoxNzA1NDQwMDAwfQ.old_signature
X-Authorization-Reset: true
Content-Type: application/json

{
  "first_name": "John"
}
```

**Response** (201 Created):
```
HTTP/1.1 201 Created
X-Authorization-Expire: "2025-01-23 04:36:29 +0000"
X-Authorization-Reset: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxMjMsInZlcmlmaWVyX3Rva2VuIjoiYWJjMTIzIiwiZ2VuZXJhdGVkX2F0IjoxNzA1NTIwMDAwfQ.new_signature"
Content-Type: application/json

{
  "id": 123,
  "first_name": "John",
  "last_name": "Doe",
  ...
}
```

#### Client Implementation Steps

1. **Include Refresh Header**: Add `X-Authorization-Reset: true` to request when refresh is needed
2. **Check Response Headers**: Look for `X-Authorization-Reset` in response headers
3. **Extract New Token**: If present, extract the new token value
4. **Update Stored Token**: Replace stored token with new token
5. **Use New Token**: Use new token for all subsequent requests

**Example Client Implementation** (pseudo-code):
```javascript
async function makeAuthenticatedRequest(url, options = {}) {
  const token = getStoredToken();

  // Check if token needs refresh
  if (shouldRefreshToken()) {
    options.headers = options.headers || {};
    options.headers['X-Authorization-Reset'] = 'true';
  }

  options.headers = options.headers || {};
  options.headers['Authorization'] = `Bearer ${token}`;

  const response = await fetch(url, options);

  // Check for new token in response
  const newToken = response.headers.get('X-Authorization-Reset');
  if (newToken) {
    storeToken(newToken);
  }

  // Update expiration time
  const expiration = response.headers.get('X-Authorization-Expire');
  if (expiration) {
    updateTokenExpiration(expiration);
  }

  return response;
}
```

#### Important Notes

- **No Special Endpoint**: Token refresh doesn't require a special endpoint - it works on any authenticated endpoint
- **Minimal Latency**: Token refresh adds minimal latency to requests
- **Old Token Validity**: The old token remains valid until it expires, but using the new token is recommended
- **Use Judiciously**: Only refresh when necessary to avoid unnecessary overhead

### 2.7 Token Invalidation

#### Verifier Token Reset Mechanism

Each user has a `verifier_token` stored in the database. This token is included in every JWT token payload. When a user's `verifier_token` is reset, **all existing JWT tokens become invalid**, effectively logging the user out of all sessions.

#### When Verifier Token is Reset

The verifier token can be reset:
- **By the user**: Via user settings/account management
- **By an admin**: Via admin user management
- **Automatically**: When security events occur (configurable)

#### How to Reset Verifier Token

**Endpoint**: `POST /user/modify` (for user) or `POST /admin/modify` (for admin)

**Request** (User):
```
POST /user/modify
Authorization: Bearer {token}
Content-Type: application/json

{
  "verifier_token": true
}
```

**Request** (Admin modifying another user):
```
POST /admin/modify
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "user_id": 123,
  "verifier_token": true
}
```

**Response** (201 Created):
```json
{
  "id": 123,
  "username": "johndoe",
  "email": "john@example.com",
  "verifier_token": "new_verifier_token_xyz",
  ...
}
```

**Note**: The `verifier_token` field accepts boolean values: `true`, `false`, `"true"`, `"false"`, `1`, `0`, `"1"`, `"0"`.

#### Token Invalidation Flow

1. **User/Admin Request**: User or admin requests verifier token reset
2. **Token Generation**: System generates a new random `verifier_token`
3. **Database Update**: User's `verifier_token` is updated in database
4. **All Tokens Invalid**: All existing JWT tokens (which contain the old `verifier_token`) become invalid
5. **New Login Required**: User must log in again to get a new token with the new `verifier_token`

#### Use Cases

- **Logout All Sessions**: User wants to log out of all devices
- **Security Breach**: Suspected account compromise
- **Password Change**: `POST /auth/password/change` automatically rotates `verifier_token` in the same transaction as the password digest update — all sessions (including the current one) are invalidated and the user must Sign In again. See [change_password_workflow.md](change_password_workflow.md).
- **Admin Action**: Admin forces user to re-authenticate

Manual verifier reset via `POST /user/modify` with `verifier_token: true` remains available for logout-all without a password change.

---

## Authorization System (RBAC)

### 3.1 Overview

CommandTower uses **RBAC (Role-Based Access Control)** for authorization. After a user is authenticated, the system checks if the user has the necessary role(s) to perform the requested action.

**Key Principle**: Authentication answers "Who are you?" Authorization answers "What are you allowed to do?"

### 3.2 Core Concepts

#### Roles

A **Role** is a named permission group that defines what actions a user can perform. Roles are assigned to users and checked against controller/action combinations.

**Example Roles**:
- `owner`: Full access to everything
- `admin`: Admin panel access
- `admin-read-only`: Read-only admin access
- `user`: Basic user access

#### Entities

An **Entity** defines which controller actions a role can access. Entities map roles to specific controllers and methods.

**Entity Structure**:
- **Name**: Unique identifier for the entity
- **Controller**: The controller class this entity applies to
- **Only**: (Optional) List of specific actions this entity allows
- **Except**: (Optional) List of actions this entity excludes

**Example Entity**:
```yaml
- name: admin
  controller: CommandTower::AdminController
  # No 'only' or 'except' means all actions are allowed
```

```yaml
- name: admin-read-only
  controller: CommandTower::AdminController
  only: [show]  # Only 'show' action is allowed
```

```yaml
- name: admin-without-impersonate
  controller: CommandTower::AdminController
  except: [impersonate]  # All actions except 'impersonate'
```

#### Role-Entity Relationships

Roles contain one or more entities. When checking authorization:
1. System finds all roles assigned to the user
2. For each role, checks if any of its entities match the requested controller/action
3. If at least one role's entity matches and authorizes the action, access is granted

### 3.3 Authorization Requirements

#### When Authorization is Required

Authorization is required for any endpoint that uses the `before_action :authorize_user!` callback.

**Important**: Authorization **must** come **after** authentication:

```ruby
class MyController < CommandTower::ApplicationController
  before_action :authenticate_user!  # Must come first
  before_action :authorize_user!      # Must come after authentication
end
```

#### Routes That Require Authorization

By default, authorization is required for:
- Admin endpoints (`/admin/*`)
- Message blast endpoints (`/inbox/blast/*`)
- Any custom endpoints that include `authorize_user!`

#### Authorization Check Process

1. **Authentication First**: `authenticate_user!` must succeed and set `current_user`
2. **Route Mapping Check**: System checks if the controller/action combination requires authorization
3. **Role Matching**: System checks if `current_user.roles` includes any role that authorizes this action
4. **Entity Matching**: For each matching role, checks if any entity matches the controller/action
5. **Authorization Result**: If at least one role authorizes the action, access is granted; otherwise, `403 Forbidden` is returned

### 3.4 Role Definitions

#### Default Roles

CommandTower includes several default roles defined in `lib/command_tower/authorization/default.yml`:

**1. `owner`**
- **Description**: The owner of the application will have full access to all components
- **Special Property**: `allow_everything: true` - bypasses all authorization checks
- **Use Case**: Super admin or application owner

**2. `admin`**
- **Description**: Full admin read and write operations. Can view and update other users' states.
- **Entities**:
  - `admin` (all AdminController actions)
  - `message-blast` (all MessageBlastController actions)
- **Use Case**: Full administrative access

**3. `admin-without-impersonation`**
- **Description**: Admin read and write operations, but impersonation is not permitted
- **Entities**:
  - `admin-without-impersonate` (AdminController except `impersonate` action)
  - `message-blast` (all MessageBlastController actions)
- **Use Case**: Admin users who shouldn't be able to impersonate others

**4. `admin-read-only`**
- **Description**: Admin read interface only
- **Entities**:
  - `read-admin` (AdminController `show` action only)
  - `message-blast-read-only` (MessageBlastController `metadata` action only)
- **Use Case**: Read-only admin access for auditing or reporting

#### Custom Role Creation via YAML

You can define custom roles in a YAML file (default: `config/rbac_groups.yml`).

**Configuration**:
```ruby
# config/initializers/command_tower.rb
CommandTower.config.authorization.rbac_group_path = Rails.root.join("config", "custom_rbac.yml")
```

**YAML Structure**:
```yaml
groups:
  my-custom-role:
    description: "Description of what this role allows"
    entities:
      - entity-name-1
      - entity-name-2

entities:
  - name: entity-name-1
    controller: MyApp::MyController
    only: [index, show]  # Optional: only these actions

  - name: entity-name-2
    controller: MyApp::AnotherController
    except: [delete]  # Optional: all actions except these
```

**Example Custom Role**:
```yaml
groups:
  content-manager:
    description: "Can manage content but not users"
    entities:
      - content-admin
      - content-read

entities:
  - name: content-admin
    controller: MyApp::ContentController
    except: [delete]

  - name: content-read
    controller: MyApp::ContentController
    only: [index, show]
```

#### Custom Role Creation via Code

For complex authorization logic, you can define roles and entities programmatically:

```ruby
# In an initializer or config file

# 1. Create Entity
entity = CommandTower::Authorization::Entity.create_entity(
  name: "custom-entity",
  controller: MyApp::MyController,
  only: [:index, :show]
)

# 2. Create Role
role = CommandTower::Authorization::Role.create_role(
  name: "custom-role",
  description: "Custom role description",
  entities: [entity],
  allow_everything: false
)
```

**Custom Entity Authorization**:

You can create custom entity classes with custom authorization logic:

```ruby
class CustomEntity < CommandTower::Authorization::Entity
  def authorized?(user:)
    # Custom logic here
    # Return true if user is authorized, false otherwise
    user.some_custom_attribute == "allowed_value"
  end
end

entity = CustomEntity.create_entity(
  name: "custom-entity",
  controller: MyApp::MyController
)
```

### 3.5 Entity Definitions

#### Entity Structure

Entities define which controller actions a role can access:

**Required Fields**:
- `name` (String): Unique identifier for the entity
- `controller` (Class or String): The controller class this entity applies to

**Optional Fields**:
- `only` (Array of Symbols): List of specific actions this entity allows
- `except` (Array of Symbols): List of actions this entity excludes

**Constraints**:
- `only` and `except` cannot both be specified
- If neither is specified, all actions on the controller are allowed

#### Entity Matching Logic

When checking if an entity matches a request:

1. **Controller Match**: Entity's controller must match the request's controller
2. **Action Match**:
   - If `only` is specified: Action must be in the `only` list
   - If `except` is specified: Action must NOT be in the `except` list
   - If neither is specified: All actions match

**Example**:
```yaml
- name: read-only-admin
  controller: CommandTower::AdminController
  only: [show, index]
```

This entity matches:
- `AdminController#show` ✓
- `AdminController#index` ✓
- `AdminController#modify` ✗ (not in `only` list)

### 3.6 Authorization Validation Process

#### Step-by-Step Process

When `authorize_user!` is called:

1. **Check Current User**: Verifies `current_user` is set (from authentication)
2. **Check Authorization Required**: Determines if the controller/action requires authorization
3. **Get User Roles**: Retrieves all roles assigned to `current_user`
4. **Find Matching Roles**: Finds all Role objects that match the user's role names
5. **Check Each Role**: For each matching role:
   - If role has `allow_everything: true`, authorization is granted
   - Otherwise, checks if any entity in the role matches the controller/action
   - For matching entities, calls `entity.authorized?(user:)` for custom logic
6. **Authorization Result**: If at least one role authorizes the action, access is granted

#### Code Flow

```ruby
# In CommandTower::Authorize::Validate
def call
  # 1. Check if authorization is required for this route
  return unless authorization_required?

  # 2. Get user's role objects
  user_role_objects = CommandTower::Authorization::Role.roles.select do |role_name, _|
    user.roles.include?(role_name.to_s)
  end

  # 3. Check if any role authorizes the action
  authorization_result = user_role_objects.any? do |_role_name, role_object|
    result = role_object.authorized?(controller:, method:, user:)
    result[:authorized] == true
  end

  # 4. Fail if not authorized
  context.fail!(msg: "Unauthorized Access. Incorrect User Privileges") unless authorization_result
end
```

#### Role Authorization Check

```ruby
# In CommandTower::Authorization::Role
def authorized?(controller:, method:, user:)
  # 1. Check if role allows everything
  return { authorized: true } if allow_everything

  # 2. Find entities that match this controller
  matched_controllers = controller_entity_mapping[controller]
  return { authorized: nil } if matched_controllers.nil?

  # 3. Check each entity
  rejected_entities = matched_controllers.map do |entity|
    case entity.matches?(controller:, method:)
    when true
      # Entity matches, check custom authorization
      entity.authorized?(user:) ? nil : { authorized: false, ... }
    when false, nil
      { authorized: false, ... }
    end
  end.compact

  # 4. Return result
  rejected_entities.empty? ? { authorized: true } : { authorized: false }
end
```

### 3.7 Authorization Failure (403 Forbidden)

#### When 403 is Returned

A `403 Forbidden` status is returned when:
- User is **authenticated** (has valid token)
- User **lacks required role(s)** for the requested action
- User's roles don't match any role that authorizes the controller/action combination

#### Error Response Format

**Response** (403 Forbidden):
```json
{
  "status": "403",
  "message": "Unauthorized Access. Incorrect User Privileges"
}
```

**Response Schema**:
- `status` (String, required): HTTP status code as string ("403")
- `message` (String, required): Error message describing the authorization failure

#### Example Scenarios

**Scenario 1: User Without Admin Role Tries to Access Admin Endpoint**

**Request**:
```
GET /admin/
Authorization: Bearer {user_token}
```

**User's Roles**: `["user"]`

**Response** (403 Forbidden):
```json
{
  "status": "403",
  "message": "Unauthorized Access. Incorrect User Privileges"
}
```

**Scenario 2: Read-Only Admin Tries to Modify User**

**Request**:
```
POST /admin/modify
Authorization: Bearer {read_only_admin_token}
Content-Type: application/json

{
  "user_id": 123,
  "email": "newemail@example.com"
}
```

**User's Roles**: `["admin-read-only"]`

**Response** (403 Forbidden):
```json
{
  "status": "403",
  "message": "Unauthorized Access. Incorrect User Privileges"
}
```

**Reason**: `admin-read-only` role only allows `show` action on `AdminController`, not `modify`.

**Scenario 3: Admin Without Impersonation Tries to Impersonate**

**Request**:
```
POST /admin/impersonate
Authorization: Bearer {admin_without_impersonation_token}
Content-Type: application/json

{
  "user_id": 123
}
```

**User's Roles**: `["admin-without-impersonation"]`

**Response** (403 Forbidden):
```json
{
  "status": "403",
  "message": "Unauthorized Access. Incorrect User Privileges"
}
```

**Reason**: `admin-without-impersonation` role explicitly excludes the `impersonate` action.

#### Debugging Authorization Failures

To debug why authorization failed:

1. **Check User Roles**: Verify what roles are assigned to the user
2. **Check Role Definitions**: Verify what entities each role contains
3. **Check Entity Matching**: Verify if entities match the controller/action
4. **Check Custom Authorization**: If entities have custom `authorized?` methods, check their logic

**Example Debug Flow**:
```ruby
# In Rails console
user = User.find(123)
puts "User roles: #{user.roles}"

role = CommandTower::Authorization::Role.roles["admin"]
puts "Role entities: #{role.entities.map(&:name)}"

entity = role.entities.first
result = entity.matches?(controller: CommandTower::AdminController, method: "modify")
puts "Entity matches: #{result}"

auth_result = role.authorized?(
  controller: CommandTower::AdminController,
  method: "modify",
  user: user
)
puts "Authorization result: #{auth_result}"
```

---

## Integration Guide

### 4.1 Setting Up Authentication

#### Controller Setup

To require authentication on a controller:

```ruby
class MyController < CommandTower::ApplicationController
  before_action :authenticate_user!

  def my_action
    # current_user is available here
    render json: { message: "Hello, #{current_user.username}" }
  end
end
```

#### Route Configuration

Routes are automatically configured when you mount the CommandTower engine. Authentication is handled at the controller level via `before_action`.

#### Error Handling

Authentication failures automatically return `401 Unauthorized` responses. You don't need to handle this manually - the `authenticate_user!` method handles it.

**Example Error Response**:
```json
{
  "status": "401",
  "message": "Bearer token missing"
}
```

### 4.2 Setting Up Authorization

#### Controller Setup

To require authorization on a controller:

```ruby
class MyController < CommandTower::ApplicationController
  # Order is important: authentication must come before authorization
  before_action :authenticate_user!
  before_action :authorize_user!

  def my_action
    # User is authenticated AND authorized here
    render json: { message: "Authorized action" }
  end
end
```

#### Defining Custom Roles

**Option 1: YAML Configuration**

Create `config/rbac_groups.yml`:

```yaml
groups:
  content-manager:
    description: "Can manage content"
    entities:
      - content-entity

entities:
  - name: content-entity
    controller: MyApp::ContentController
    except: [delete]
```

**Option 2: Code Configuration**

In an initializer:

```ruby
# config/initializers/command_tower_roles.rb

# Create entity
entity = CommandTower::Authorization::Entity.create_entity(
  name: "content-entity",
  controller: MyApp::ContentController,
  except: [:delete]
)

# Create role
CommandTower::Authorization::Role.create_role(
  name: "content-manager",
  description: "Can manage content",
  entities: [entity]
)
```

#### Assigning Roles to Users

Roles are stored as an array on the User model. You can assign roles:

```ruby
# In Rails console or service
user = User.find(123)
user.roles = ["content-manager", "user"]
user.save!
```

Or via admin endpoint:

```
POST /admin/modify/role
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "user_id": 123,
  "roles": ["content-manager", "user"]
}
```

### 4.3 Client Implementation

#### Token Storage

**Best Practices**:
- **Web Applications**: Use secure HTTP-only cookies (most secure)
- **Mobile Applications**: Use secure keychain/keystore
- **Never**: Store tokens in localStorage (vulnerable to XSS)

**Example (React with secure storage)**:
```javascript
// Store token
function storeToken(token) {
  // Use secure storage mechanism
  SecureStore.setItemAsync('auth_token', token);
}

// Retrieve token
async function getToken() {
  return await SecureStore.getItemAsync('auth_token');
}
```

#### Token Refresh Implementation

**Recommended Strategy**:

1. **Monitor Expiration**: Check `X-Authorization-Expire` header on every response
2. **Refresh Proactively**: Refresh when less than 5 minutes remain
3. **Handle Errors**: If refresh fails, redirect to login

**Example Implementation**:
```javascript
class AuthService {
  constructor() {
    this.token = null;
    this.expirationTime = null;
  }

  async makeRequest(url, options = {}) {
    // Check if token needs refresh
    if (this.shouldRefreshToken()) {
      options.headers = options.headers || {};
      options.headers['X-Authorization-Reset'] = 'true';
    }

    // Add authorization header
    if (this.token) {
      options.headers = options.headers || {};
      options.headers['Authorization'] = `Bearer ${this.token}`;
    }

    const response = await fetch(url, options);

    // Update token if refreshed
    const newToken = response.headers.get('X-Authorization-Reset');
    if (newToken) {
      this.token = newToken;
      this.storeToken(newToken);
    }

    // Update expiration
    const expiration = response.headers.get('X-Authorization-Expire');
    if (expiration) {
      this.expirationTime = new Date(expiration);
    }

    return response;
  }

  shouldRefreshToken() {
    if (!this.expirationTime) return false;

    const now = new Date();
    const timeRemaining = this.expirationTime - now;
    const fiveMinutes = 5 * 60 * 1000;

    return timeRemaining < fiveMinutes;
  }

  storeToken(token) {
    // Implement secure storage
    localStorage.setItem('auth_token', token); // Not recommended for production
  }
}
```

#### Handling 401 Errors

When a `401 Unauthorized` is received:

1. **Clear Stored Token**: Remove invalid token from storage
2. **Redirect to Login**: Redirect user to login page
3. **Show Error Message**: Inform user that their session expired

**Example**:
```javascript
async function handleResponse(response) {
  if (response.status === 401) {
    // Clear token
    await clearStoredToken();

    // Redirect to login
    window.location.href = '/login';

    // Show error
    showError('Your session has expired. Please log in again.');
  }

  return response;
}
```

#### Handling 403 Errors

When a `403 Forbidden` is received:

1. **Show Error Message**: Inform user they don't have permission
2. **Redirect if Appropriate**: Redirect to a page they can access
3. **Log for Admin**: Log the authorization failure for admin review

**Example**:
```javascript
async function handleResponse(response) {
  if (response.status === 403) {
    const error = await response.json();

    // Show error
    showError(error.message || 'You do not have permission to perform this action.');

    // Optionally redirect
    // window.location.href = '/dashboard';
  }

  return response;
}
```

---

## Configuration

### 5.1 JWT Configuration

JWT configuration is done in the CommandTower initializer:

```ruby
# config/initializers/command_tower.rb

CommandTower.configure do |config|
  # JWT Configuration
  config.jwt.ttl = 7.days  # Default: 7.days
  config.jwt.hmac_secret = ENV['SECRET_KEY_BASE']  # Default: ENV['SECRET_KEY_BASE']
end
```

#### Configuration Options

**`config.jwt.ttl`**
- **Type**: `ActiveSupport::Duration`
- **Default**: `7.days`
- **Description**: How long JWT tokens remain valid
- **Example**: `config.jwt.ttl = 24.hours`

**`config.jwt.hmac_secret`**
- **Type**: `String`
- **Default**: `ENV['SECRET_KEY_BASE']` or fallback secret
- **Description**: Secret key used to sign and verify JWT tokens
- **Security**: Should be a strong, random secret (use `ENV['SECRET_KEY_BASE']` in production)

### 5.2 Authorization Configuration

Authorization configuration is done in the CommandTower initializer:

```ruby
# config/initializers/command_tower.rb

CommandTower.configure do |config|
  # Authorization Configuration
  config.authorization.rbac_default_groups = true  # Default: true
  config.authorization.rbac_group_path = Rails.root.join("config", "rbac_groups.yml")  # Default
end
```

#### Configuration Options

**`config.authorization.rbac_default_groups`**
- **Type**: `Boolean`
- **Default**: `true`
- **Description**: Whether to load default roles (`owner`, `admin`, etc.)
- **Recommendation**: Keep as `true` unless you want to define all roles yourself

**`config.authorization.rbac_group_path`**
- **Type**: `String` (file path)
- **Default**: `Rails.root.join("config", "rbac_groups.yml")`
- **Description**: Path to YAML file containing custom role definitions
- **Example**: `config.authorization.rbac_group_path = Rails.root.join("config", "custom_roles.yml")`

---

## Security Considerations

### 6.1 Token Security

#### Secure Token Storage

**Web Applications**:
- Use **HTTP-only cookies** (prevents XSS attacks)
- Set `Secure` flag (HTTPS only)
- Set `SameSite` attribute appropriately

**Mobile Applications**:
- Use **secure keychain/keystore** (iOS Keychain, Android Keystore)
- Never store in plain text files
- Use platform-specific secure storage APIs

**Never**:
- Store tokens in `localStorage` (vulnerable to XSS)
- Store tokens in `sessionStorage` (vulnerable to XSS)
- Log tokens in client-side code
- Include tokens in URLs

#### Token Transmission

- **Always use HTTPS** in production
- Never send tokens over unencrypted connections
- Use secure headers (`Strict-Transport-Security`)

#### Token Expiration

- **Set appropriate TTL**: Balance security (shorter) vs. user experience (longer)
- **Monitor expiration**: Refresh tokens before expiration
- **Handle expiration gracefully**: Redirect to login when tokens expire

#### Token Invalidation

- **Reset verifier_token** when:
  - User logs out
  - Password is changed
  - Security breach is suspected
  - Admin forces re-authentication

### 6.2 Authorization Security

#### Role Assignment Security

- **Principle of Least Privilege**: Assign minimum necessary roles
- **Regular Audits**: Review user roles periodically
- **Admin-Only Assignment**: Only allow admins to assign roles
- **Audit Logging**: Log all role changes

#### Entity Definition Security

- **Validate Controllers**: Ensure entity controllers exist and are correct
- **Test Authorization**: Test authorization logic thoroughly
- **Document Roles**: Document what each role allows
- **Review Custom Logic**: Review custom `authorized?` methods for security issues

#### Principle of Least Privilege

- **Default Deny**: By default, users should have no special permissions
- **Explicit Allow**: Explicitly grant permissions via roles
- **Regular Review**: Periodically review and remove unnecessary permissions

---

## Troubleshooting

### 7.1 Common Authentication Issues

#### Issue: "Bearer token missing"

**Symptoms**: `401 Unauthorized` with message "Bearer token missing"

**Causes**:
- Request doesn't include `Authorization` header
- Header is empty or nil

**Solutions**:
1. Ensure request includes `Authorization: Bearer {token}` header
2. Check that token is being sent correctly from client
3. Verify token is stored and retrieved correctly

#### Issue: "Invalid Bearer token format"

**Symptoms**: `401 Unauthorized` with message "Invalid Bearer token format"

**Causes**:
- Header format is incorrect
- Missing space between "Bearer" and token
- Case sensitivity issues

**Solutions**:
1. Ensure header format is exactly: `Authorization: Bearer {token}`
2. Check for extra spaces or missing spaces
3. Verify "Bearer" is capitalized correctly

#### Issue: "Unauthorized Access. Invalid Authorization token"

**Symptoms**: `401 Unauthorized` with message "Unauthorized Access. Invalid Authorization token"

**Causes**:
- Token is expired
- Token cannot be decoded (invalid signature)
- Token payload is malformed
- User ID in token doesn't exist

**Solutions**:
1. Check token expiration: Verify `X-Authorization-Expire` header
2. Verify token wasn't tampered with
3. Ensure user still exists in database
4. Request new token via login

#### Issue: "Unauthorized Access. Token is no longer valid"

**Symptoms**: `401 Unauthorized` with message "Unauthorized Access. Token is no longer valid"

**Causes**:
- User's `verifier_token` was reset
- Token contains old `verifier_token` that no longer matches

**Solutions**:
1. User must log in again to get new token
2. Check if verifier_token was reset (intentionally or accidentally)
3. Verify user account is still active

#### Issue: "Email must be verified to continue"

**Symptoms**: `412 Precondition Failed` with message about email validation

**Causes**:
- Email verification is enabled
- User's email is not validated

**Solutions**:
1. User must verify email via `/auth/email/verify` endpoint
2. Or use `authenticate_user_without_email_verification!` for specific endpoints

### 7.2 Common Authorization Issues

#### Issue: 403 Forbidden on Authorized Route

**Symptoms**: `403 Forbidden` when user should have access

**Causes**:
- User doesn't have required role
- Role doesn't include entity for this controller/action
- Entity doesn't match the controller/action

**Solutions**:
1. Check user's roles: `user.roles`
2. Verify role definitions include correct entities
3. Check entity matches controller and action
4. Review custom authorization logic if applicable

**Debug Steps**:
```ruby
# In Rails console
user = User.find(123)
puts "User roles: #{user.roles.inspect}"

role = CommandTower::Authorization::Role.roles["admin"]
puts "Role entities: #{role.entities.map(&:name)}"

# Check if route requires authorization
controller = CommandTower::AdminController
action = "modify"
mapped = CommandTower::Authorization.mapped_controllers[controller]
puts "Route requires authorization: #{mapped&.include?(action.to_sym)}"

# Check authorization result
result = CommandTower::Authorize::Validate.(
  user: user,
  controller: controller,
  method: action
)
puts "Authorization result: #{result.success?} - #{result.msg}"
```

#### Issue: Authorization Not Being Checked

**Symptoms**: User can access route without proper role

**Causes**:
- `authorize_user!` not called in controller
- Route not mapped for authorization
- User has `owner` role (bypasses all checks)

**Solutions**:
1. Ensure `before_action :authorize_user!` is in controller
2. Verify route is mapped for authorization
3. Check if user has `owner` role (which bypasses checks)

---

## Examples and Use Cases

### 8.1 Complete Authentication Flow

**Step 1: User Registration**

```
POST /auth/create
Content-Type: application/json

{
  "first_name": "John",
  "last_name": "Doe",
  "username": "johndoe",
  "email": "john@example.com",
  "password": "securepassword123",
  "password_confirmation": "securepassword123"
}
```

**Response** (201 Created):
```json
{
  "full_name": "John Doe",
  "first_name": "John",
  "last_name": "Doe",
  "username": "johndoe",
  "email": "john@example.com",
  "msg": "Successfully created new User"
}
```

**Step 2: User Login**

```
POST /auth/login
Content-Type: application/json

{
  "identifier": "johndoe",
  "password": "securepassword123"
}
```

**Response** (201 Created):
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "header_name": "Authorization",
  "message": "Successfully logged user in",
  "user": { ... }
}
```

**Step 3: Make Authenticated Request**

```
GET /user/
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response** (200 OK):
```
X-Authorization-Expire: "2025-01-16 04:36:29 +0000"
Content-Type: application/json

{
  "id": 123,
  "username": "johndoe",
  ...
}
```

### 8.2 Complete Authorization Flow

**Scenario**: Admin user accessing admin endpoint

**Step 1: Login as Admin**

```
POST /auth/login
Content-Type: application/json

{
  "identifier": "admin",
  "password": "adminpassword"
}
```

**Response**: Returns token for user with `roles: ["admin"]`

**Step 2: Access Admin Endpoint**

```
GET /admin/
Authorization: Bearer {admin_token}
```

**Authorization Check**:
1. ✅ Authentication succeeds (valid token)
2. ✅ `current_user` is set
3. ✅ Route requires authorization (`/admin/` is mapped)
4. ✅ User has `admin` role
5. ✅ `admin` role includes `admin` entity
6. ✅ `admin` entity matches `AdminController#show`
7. ✅ Authorization succeeds

**Response** (200 OK):
```json
{
  "id": 1,
  "username": "admin",
  ...
}
```

**Step 3: Non-Admin User Tries Same Endpoint**

```
GET /admin/
Authorization: Bearer {user_token}
```

**Authorization Check**:
1. ✅ Authentication succeeds (valid token)
2. ✅ `current_user` is set
3. ✅ Route requires authorization
4. ❌ User has `["user"]` role, not `admin`
5. ❌ No matching role authorizes this action
6. ❌ Authorization fails

**Response** (403 Forbidden):
```json
{
  "status": "403",
  "message": "Unauthorized Access. Incorrect User Privileges"
}
```

### 8.3 Token Refresh Flow

**Scenario**: Token is about to expire, client refreshes it

**Step 1: Make Request with Refresh Header**

```
POST /user/modify
Authorization: Bearer {old_token}
X-Authorization-Reset: true
Content-Type: application/json

{
  "first_name": "John Updated"
}
```

**Step 2: Server Response with New Token**

**Response** (201 Created):
```
X-Authorization-Expire: "2025-01-23 04:36:29 +0000"
X-Authorization-Reset: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.{new_token_payload}.{new_signature}"
Content-Type: application/json

{
  "id": 123,
  "first_name": "John Updated",
  ...
}
```

**Step 3: Client Updates Token**

Client extracts new token from `X-Authorization-Reset` header and stores it for future requests.

**Step 4: Use New Token**

All subsequent requests use the new token from `X-Authorization-Reset`.

### 8.4 Custom Role Implementation

**Scenario**: Create a custom "content-manager" role

**Step 1: Define Entity and Role in YAML**

Create `config/rbac_groups.yml`:

```yaml
groups:
  content-manager:
    description: "Can manage content but not delete"
    entities:
      - content-entity

entities:
  - name: content-entity
    controller: MyApp::ContentController
    except: [delete]
```

**Step 2: Assign Role to User**

```
POST /admin/modify/role
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "user_id": 123,
  "roles": ["content-manager", "user"]
}
```

**Step 3: User Accesses Content Endpoint**

```
GET /content/
Authorization: Bearer {content_manager_token}
```

**Authorization Check**:
1. ✅ Authentication succeeds
2. ✅ User has `content-manager` role
3. ✅ `content-manager` role includes `content-entity`
4. ✅ `content-entity` matches `ContentController#index` (not in `except` list)
5. ✅ Authorization succeeds

**Step 4: User Tries to Delete Content**

```
DELETE /content/456
Authorization: Bearer {content_manager_token}
```

**Authorization Check**:
1. ✅ Authentication succeeds
2. ✅ User has `content-manager` role
3. ✅ `content-manager` role includes `content-entity`
4. ❌ `content-entity` does NOT match `ContentController#delete` (in `except` list)
5. ❌ Authorization fails

**Response** (403 Forbidden):
```json
{
  "status": "403",
  "message": "Unauthorized Access. Incorrect User Privileges"
}
```

---

## API Reference

### 9.1 Authentication Headers

#### Request Headers

**`Authorization`** (Required for authenticated endpoints)
- **Format**: `Bearer {token}`
- **Example**: `Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
- **Purpose**: Identifies the authenticated user

**`X-Authorization-Reset`** (Optional)
- **Format**: `true`, `"true"`, `1`, or `"1"`
- **Example**: `X-Authorization-Reset: true`
- **Purpose**: Requests token refresh

#### Response Headers

**`X-Authorization-Expire`** (All authenticated requests)
- **Format**: ISO 8601 timestamp string
- **Example**: `X-Authorization-Expire: "2025-01-16 04:36:29 +0000"`
- **Purpose**: Indicates when the current token will expire

**`X-Authorization-Reset`** (Only when refresh requested)
- **Format**: JWT token string
- **Example**: `X-Authorization-Reset: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
- **Purpose**: Contains the new token when refresh is requested

### 9.2 Authorization Headers

Authorization uses the same `Authorization` header as authentication. The authorization check occurs after authentication succeeds.

### 9.3 Response Headers Summary

| Header | Request/Response | When Present | Purpose |
|--------|------------------|--------------|---------|
| `Authorization` | Request | All authenticated endpoints | Bearer token for authentication |
| `X-Authorization-Reset` | Request | When token refresh needed | Requests token refresh |
| `X-Authorization-Expire` | Response | All authenticated requests | Token expiration timestamp |
| `X-Authorization-Reset` | Response | When refresh requested | New token value |

### 9.4 Error Response Formats

#### Authentication Errors (401)

**Format**:
```json
{
  "status": "401",
  "message": "Error message describing the issue"
}
```

**Common Messages**:
- `"Bearer token missing"`
- `"Invalid Bearer token format"`
- `"Unauthorized Access. Invalid Authorization token"`
- `"Unauthorized Access. Token is no longer valid"`

#### Email Validation Errors (412)

**Format**:
```json
{
  "status": "412",
  "message": "Email must be verified to continue",
  "meta": {
    "email_validated": false
  }
}
```

**Common Messages**:
- `"Email must be verified to continue"`

#### Authorization Errors (403)

**Format**:
```json
{
  "status": "403",
  "message": "Unauthorized Access. Incorrect User Privileges"
}
```

#### Validation Errors (400)

**Format**:
```json
{
  "status": "400",
  "message": "Error message",
  "invalid_arguments": {
    "field_name": ["Error message for field"]
  }
}
```

**Example**:
```json
{
  "status": "400",
  "message": "Invalid arguments provided",
  "invalid_arguments": {
    "email": ["Invalid email address"],
    "password": ["Parameter [password] is required but not present"]
  }
}
```

---

## Conclusion

This guide has covered the complete authentication and authorization system in CommandTower. Key takeaways:

1. **Authentication** uses JWT tokens and validates user identity
2. **Authorization** uses RBAC to check user permissions
3. **Tokens** expire based on TTL configuration and can be refreshed
4. **Roles** define what users can do, **Entities** define which actions roles allow
5. **401** means authentication failed, **403** means authorization failed

For additional information, refer to:
- [API Reference](api_reference.md)
- [Initialization Guide](initializing.md)
- [Models Documentation](models.md)
