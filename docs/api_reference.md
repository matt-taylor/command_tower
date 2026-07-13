# CommandTower API Reference

## Table of Contents
1. [High-Level Overview](#high-level-overview)
2. [Authentication & Token Management](#authentication--token-management)
3. [Request/Response Format](#requestresponse-format)
4. [Authentication Endpoints](#authentication-endpoints)
5. [User Management Endpoints](#user-management-endpoints)
6. [Username Availability](#username-availability)
7. [Roles and Authorization (RBAC)](#roles-and-authorization-rbac)
8. [Admin Endpoints](#admin-endpoints)
9. [Inbox Endpoints](#inbox-endpoints)
10. [Complete Workflows](#complete-workflows)
11. [Error Handling](#error-handling)

**Note**: All authentication token extraction and management is handled by the centralized `CommandTower::Jwt::AuthorizationHelper` module. This ensures consistent behavior across all endpoints and abstracts header/cookie access logic.

---

## High-Level Overview

CommandTower is an API-only Rails engine that provides:
- **Authentication**: JWT-based bearer token authentication
- **Authorization**: RBAC (Role-Based Access Control) with configurable roles
- **User Management**: User registration, login, profile management
- **Admin Functions**: User administration and role management
- **Inbox System**: Messaging and message blast functionality

### Base URL
All endpoints are mounted under the CommandTower engine route (configured during initialization via the Rails generator).

### Content Type
All requests should use `Content-Type: application/json` header.

All responses are returned as `Content-Type: application/json`.

---

## Authentication & Token Management

CommandTower supports two authentication methods:
1. **Header-based authentication** (default): `Authorization: Bearer {token}` header
2. **Cookie-based authentication** (optional): HttpOnly cookies for web applications

**📖 For web applications using cookie authentication**, see the comprehensive [Cookie Authentication Guide](cookie_authentication_guide.md) for setup instructions, CORS configuration, and best practices.

### Authentication Header Format

For all authenticated endpoints, include the JWT token in the `Authorization` header:

```
Authorization: Bearer {token_value}
```

**Critical Format Requirements**:
- The header value MUST be in the format: `Bearer {token}` (with a space between "Bearer" and the token)
- The word "Bearer" is case-sensitive
- Missing or malformed headers will result in `401 Unauthorized` responses
- Malformed headers return: `"Invalid Bearer token format"`
- Missing headers return: `"Bearer token missing"`

### Cookie Authentication (Optional)

CommandTower supports HttpOnly cookie-based authentication for web applications. When enabled:

**Configuration**:
```ruby
CommandTower.configure do |config|
  config.jwt.cookie.enabled = true
  # Optional: customize cookie settings
  # config.jwt.cookie.name = "ct_jwt"  # Default: "ct_jwt"
  # config.jwt.cookie.same_site = :lax  # Default: :lax (:lax, :strict, or :none)
  # config.jwt.cookie.secure = true     # Default: false (auto-set to true in production)
  # config.jwt.cookie.path = "/"        # Default: "/"
  # config.jwt.cookie.domain = nil      # Default: nil (host-only)
  # config.jwt.cookie.ttl = 7.days      # Default: matches JWT TTL
end
```

**Authentication Priority**:
1. **Authorization Header** (checked first): `Authorization: Bearer {token}`
2. **HttpOnly Cookie** (fallback): Automatically used if header is missing and cookie auth is enabled

**Behavior**:
- On successful login, token is set in both `X-Authorization-Reset` header and HttpOnly cookie (if enabled)
- When tokens are refreshed (via `X-Authorization-Reset: true`), the cookie is automatically updated
- Use `POST /auth/logout` to clear the cookie (browser-only logout)

**Security**:
- Cookies are HttpOnly by default (not accessible via JavaScript)
- Cookies use SameSite=Lax by default to prevent CSRF attacks
- Optional double-submit CSRF protection can be enabled for additional security
- Secure flag is automatically set to `true` in production environments
- Cookie TTL matches the JWT TTL configuration

**CSRF Protection**:
- When CSRF protection is enabled, clients must send CSRF token in `X-CSRF-Token` header for unsafe methods (POST, PUT, PATCH, DELETE)
- CSRF protection only applies to cookie-authenticated requests
- Authorization header authentication is always exempt from CSRF checks
- See [Cookie Authentication Guide](cookie_authentication_guide.md) for complete CSRF setup instructions

**Example**:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxMjMsInZlcmlmaWVyX3Rva2VuIjoiYWJjMTIzIiwiZ2VuZXJhdGVkX2F0IjoxNzA1NDQwMDAwfQ.signature
```

### Token Expiration Monitoring

Every authenticated request returns a header indicating when the current token will expire:

**Response Header**:
```
X-Authorization-Expire: "2025-01-16 04:36:29 +0000"
```

**Client Implementation**:
1. Parse the timestamp from `X-Authorization-Expire` header on each response
2. Monitor the expiration time
3. Refresh the token before it expires to maintain session continuity
4. Recommended: Refresh when less than 5 minutes remain before expiration

### Token Refresh Mechanism

**How to Refresh a Token in the Same Request**

To refresh a JWT token on any authenticated request, include the following header:

**Request Header**:
```
X-Authorization-Reset: true
```

**Response Header** (when refresh is requested):
```
X-Authorization-Reset: "{new_token_value}"
```

**Complete Example**:

**Request**:
```
POST /user/modify
Authorization: Bearer {old_token}
X-Authorization-Reset: true
Content-Type: application/json

{
  "first_name": "John"
}
```

**Response**:
```
HTTP/1.1 201 Created
X-Authorization-Expire: "2025-01-16 05:36:29 +0000"
X-Authorization-Reset: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.{new_token_payload}.{new_signature}"
Content-Type: application/json

{
  "id": 123,
  "first_name": "John",
  ...
}
```

**Client Implementation Steps**:
1. Include `X-Authorization-Reset: true` in any authenticated request when you want to refresh the token
2. Check the response headers for `X-Authorization-Reset`
3. If present, extract the new token value
4. Replace your stored token with the new value
5. Use the new token for all subsequent requests

**Important Notes**:
- Token refresh adds minimal latency but should be used judiciously
- Only refresh when necessary (e.g., before expiration). After `POST /auth/password/change`, do not refresh — Sign In again.
- The old token remains valid until it expires, but using the new token is recommended
- You can refresh on any authenticated endpoint - no special refresh endpoint is needed

### Token Structure

JWT tokens contain the following encrypted payload:
- `user_id` (Integer): The authenticated user's ID
- `verifier_token` (String): A token that must match the user's current verifier_token
- `generated_at` (Integer/Timestamp): Unix timestamp when the token was created

**Token Validation**:
- If a token's `verifier_token` doesn't match the user's current `verifier_token`, authentication fails with `401 Unauthorized`
- This allows for "logout all sessions" functionality by resetting the user's verifier_token
- Tokens expire based on the JWT TTL configuration (typically 24 hours)

### Security Best Practices

1. **Token Storage**: Store tokens securely (e.g., secure HTTP-only cookies, secure storage on mobile)
2. **Token Transmission**: Always use HTTPS in production
3. **Token Expiration**: Monitor and refresh tokens before expiration
4. **Token Invalidation**: Use verifier_token reset to invalidate all sessions when needed
5. **Never Log Tokens**: Avoid logging tokens in client-side code or server logs

---

## Request/Response Format

### Request Format

**Headers**:
- `Content-Type: application/json` (required for POST/PATCH requests with body)
- `Authorization: Bearer {token}` (required for authenticated endpoints)

**Body** (for POST/PATCH requests):
- JSON object with required/optional fields as specified per endpoint

### Response Format

**Success Responses**:
- Status codes: `200 OK`, `201 Created`
- Body: JSON object matching the endpoint's response schema

**Error Responses**:
- Status codes: `400 Bad Request`, `401 Unauthorized`, `403 Forbidden`, `500 Internal Server Error`
- Body: Error schema (see [Error Handling](#error-handling) section)

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp (all authenticated requests)
- `X-Authorization-Reset`: New token value (only when refresh requested)
- `Set-Cookie`: HttpOnly cookie with JWT token (only when cookie authentication is enabled and token is set/refreshed)

### Boolean Parameter Format

Boolean values in request bodies can be sent in multiple formats:
- `true` / `false` (JSON boolean)
- `"true"` / `"false"` (string)
- `1` / `0` (integer)
- `"1"` / `"0"` (string)

All formats are accepted and converted appropriately.

---

## Authentication Endpoints

### 1. User Signup (Create Account)

**Endpoint**: `POST /auth/create`

**Authentication Required**: No

**Request Headers**:
```
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "first_name": "string (optional)",
  "last_name": "string (optional)",
  "username": "string (optional)",
  "email": "string (optional)",
  "password": "string (optional)",
  "password_confirmation": "string (optional)"
}
```

**Field Types**:
- `first_name`: String (optional)
- `last_name`: String (optional)
- `username`: String (optional)
- `email`: String (optional)
- `password`: String (optional)
- `password_confirmation`: String (optional)

**Response** (201 Created):
```json
{
  "full_name": "string",
  "first_name": "string",
  "last_name": "string",
  "username": "string",
  "email": "string",
  "msg": "string"
}
```

**Response Schema**:
- `full_name`: String (required)
- `first_name`: String (required)
- `last_name`: String (required)
- `username`: String (required)
- `email`: String (required)
- `msg`: String (required)

**Error Responses**:
- `400 Bad Request`: Invalid arguments (validation errors in `invalid_arguments` object)

**Notes**:
- This endpoint creates a new user account
- After signup, the user should log in to receive a JWT token
- If email verification is enabled, the user will need to verify their email before accessing protected endpoints
- Password and password_confirmation must match

---

### 2. User Login

**Endpoint**: `POST /auth/login`

**Authentication Required**: No

**Request Headers**:
```
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "identifier": "string (optional, can be username or email)",
  "password": "string (optional)"
}
```

**Field Types**:
- `identifier`: String (optional, can be username or email)
- `password`: String (optional)

**Response** (201 Created):
```json
{
  "token": "string",
  "header_name": "string",
  "message": "string",
  "user": {
    "id": "integer",
    "username": "string",
    "email": "string",
    "first_name": "string",
    "last_name": "string",
    "email_validated": "boolean",
    "roles": "array",
    "created_at": "string",
    "verifier_token": "string",
    "last_known_timezone": "string"
  }
}
```

**Response Schema**:
- `token`: String (required) - JWT token to use in Authorization header
- `header_name`: String (required) - Always "Authorization"
- `message`: String (required) - Success message
- `user`: Object (required) - User object with configured default attributes:
  - `id`: Integer (required)
  - `username`: String (required)
  - `email`: String (required)
  - `first_name`: String (optional, based on config)
  - `last_name`: String (optional, based on config)
  - `email_validated`: Boolean (optional, based on config)
  - `roles`: Array (optional, based on config)
  - `created_at`: String/Timestamp (optional, based on config)
  - `verifier_token`: String (optional, based on config)
  - `last_known_timezone`: String (optional, based on config)
  - Additional attributes may be included based on configuration

**Error Responses**:
- `400 Bad Request`: Invalid request format
- `401 Unauthorized`: Invalid credentials or invalid arguments

**Response Headers** (when cookie authentication is enabled):
- `X-Authorization-Reset`: JWT token value
- `X-Authorization-Expire`: Token expiration timestamp
- `Set-Cookie`: HttpOnly cookie containing the JWT token

**Notes**:
- Provide `identifier` which can be either username or email (the system will check both fields)
- The returned `token` should be used in the `Authorization: Bearer {token}` header for subsequent requests
- If cookie authentication is enabled, the token is also automatically set as an HttpOnly cookie
- If email verification is enabled and the user hasn't verified their email, they may be restricted from certain endpoints
- User object attributes are configurable via `CommandTower.config.user.default_attributes`

---

### 3. User Logout

**Endpoint**: `POST /auth/logout`

**Authentication Required**: No (but cookie will only be cleared if present)

**Request Headers**:
```
Content-Type: application/json
```

**Request Body**: None

**Response** (200 OK):
```json
{
  "message": "Logged out"
}
```

**Response Schema**:
- `message`: String (required) - "Logged out"

**Error Responses**: None (always returns 200)

**Response Headers**:
- `Set-Cookie`: Cookie is cleared (expired in the past) if cookie authentication is enabled

**Notes**:
- Clears the HttpOnly JWT cookie if cookie authentication is enabled
- This is a browser-only logout that does NOT reset the user's `verifier_token`
- To log out of all sessions (including mobile/API clients), use `POST /user/modify` with `verifier_token: true` instead
- If cookie authentication is disabled, this endpoint still returns success but performs no action
- Useful for web applications where you want to clear the browser session without invalidating tokens used by mobile apps

---

### 4. Email Verification - Send Code

**Endpoint**: `POST /auth/email/send`

**Authentication Required**: Yes (Bearer token)

**Request Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body**: None

**Response** (201 Created):
```json
{
  "message": "string"
}
```

**Response Schema**:
- `message`: String (required) - "Successfully sent Email verification code"

**Response** (200 OK - if already verified):
```json
{
  "message": "string"
}
```

**Response Schema**:
- `message`: String (required) - "Email is already verified. No code required"

**Error Responses**:
- `401 Unauthorized`: Missing or invalid token

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Sends a verification code to the user's email
- The code is stored in the system and can be verified using the verify endpoint
- If email verification is disabled in configuration, this endpoint may not be available
- User must be authenticated to request a verification code

---

### 5. Email Verification - Verify Code

**Endpoint**: `POST /auth/email/verify`

**Authentication Required**: Yes (Bearer token)

**Request Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "code": "string"
}
```

**Field Types**:
- `code`: String (required) - Verification code sent to user's email

**Response** (201 Created):
```json
{
  "message": "string"
}
```

**Response Schema**:
- `message`: String (required) - "Successfully verified email"

**Response** (200 OK - if already verified):
```json
{
  "message": "string"
}
```

**Response Schema**:
- `message`: String (required) - "Email is already verified."

**Error Responses**:
- `401 Unauthorized`: Missing or invalid token
- `403 Forbidden`: Invalid verification code or other validation error
- `400 Bad Request`: Invalid arguments

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- The code is typically a string sent to the user's email
- After successful verification, the user's `email_validated` flag is set to true
- Once verified, users can access all protected endpoints (if email verification is required)
- Invalid codes will result in 403 Forbidden

---

### 6. Password Reset - Send Email

**Endpoint**: `POST /auth/password/forgot/send`

**Authentication Required**: No

**Request Headers**:
```
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "email": "string"
}
```

**Field Types**:
- `email`: String (required) - User's email address

**Response** (200 OK):
```json
{
  "message": "string"
}
```

**Response Schema**:
- `message`: String (required) - "If an account exists with that email, a password reset link has been sent."

**Error Responses**:
- `400 Bad Request`: Invalid email format or missing email

**Notes**:
- Always returns 200 OK, even if email doesn't exist (prevents user enumeration)
- Never returns 500, even if email delivery fails (security best practice)
- Sends password reset email with token if user exists
- Token expires after configured time (default: 1 hour)
- If password reset is disabled in configuration, this endpoint may not be available

---

### 7. Password Reset - Validate Token

**Endpoint**: `POST /auth/password/forgot/validate`

**Authentication Required**: No

**Request Headers**:
```
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "token": "string"
}
```

**Field Types**:
- `token`: String (required) - Password reset token from email

**Response** (200 OK):
```json
{
  "valid": true,
  "expires_at": "string"
}
```

**Response Schema**:
- `valid`: Boolean (required) - Whether token is valid
- `expires_at`: String (optional) - Token expiration timestamp

**Error Responses**:
- `400 Bad Request`: Missing token
- `401 Unauthorized`: Invalid, expired, or used token (generic "Invalid token" message)

**Notes**:
- Validates password reset token before showing reset form
- Returns generic error message (doesn't reveal if token is expired, used, or not found)
- If password reset is disabled in configuration, this endpoint may not be available

---

### 8. Password Reset - Reset Password

**Endpoint**: `POST /auth/password/forgot/reset`

**Authentication Required**: No

**Request Headers**:
```
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "token": "string",
  "password": "string",
  "password_confirmation": "string"
}
```

**Field Types**:
- `token`: String (required) - Password reset token from email
- `password`: String (required) - New password
- `password_confirmation`: String (required) - Password confirmation (must match password)

**Response** (200 OK):
```json
{
  "message": "string"
}
```

**Response Schema**:
- `message`: String (required) - "Password has been successfully reset"

**Error Responses**:
- `400 Bad Request`: Missing token, password validation errors, password mismatch
- `401 Unauthorized`: Invalid, expired, or used token (generic "Invalid token" message)

**Notes**:
- Resets user password using token from email
- Token is single-use and invalidated after successful reset
- Returns generic error message for invalid tokens (doesn't reveal specific reason)
- Password must meet length requirements (configurable)
- If password reset is disabled in configuration, this endpoint may not be available

---

### 8b. Authenticated Password Change

**Endpoint**: `POST /auth/password/change`

**Authentication Required**: Yes (Bearer token)

**Request Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "current_password": "string",
  "password": "string",
  "password_confirmation": "string"
}
```

**Field Types**:
- `current_password`: String (required) - Caller's current password
- `password`: String (required) - New password
- `password_confirmation`: String (required) - Must match `password`

**Response** (200 OK):
```json
{
  "message": "Password has been successfully changed"
}
```

**Response Schema**:
- `message`: String (required)

**Error Responses**:
- `400 Bad Request`: Incorrect current password, confirmation mismatch, length / model validation errors
- `401 Unauthorized`: Missing or invalid JWT
- `500 Internal Server Error`: Failure to rotate session verifier (transaction rolled back)

**Notes**:
- Requires plain_text login enabled (`CommandTower.config.login.plain_text.enable?`)
- On success, rotates `verifier_token` in the same transaction as the password update — **all** existing sessions are invalidated, including the caller's
- Does **not** re-issue a JWT; the host must clear local auth and send the user through Sign In
- Distinct from public `POST /auth/password/forgot/reset` (token-based recovery; does not rotate verifier)
- See [change_password_workflow.md](change_password_workflow.md)

---

## User Management Endpoints

### 9. Get Current User

**Endpoint**: `GET /user`

**Authentication Required**: Yes (Bearer token)

**Request Headers**:
```
Authorization: Bearer {token}
```

**Request Body**: None

**Response** (200 OK):
```json
{
  "id": "integer",
  "username": "string",
  "email": "string",
  "first_name": "string",
  "last_name": "string",
  "email_validated": "boolean",
  "roles": "array",
  "created_at": "string",
  "verifier_token": "string",
  "last_known_timezone": "string"
}
```

**Response Schema**:
- User object with configured default attributes (same structure as login response user object)
- Attributes included are based on `CommandTower.config.user.default_attributes` configuration

**Error Responses**:
- `401 Unauthorized`: Missing or invalid token
- If email verification is required and not completed, may return 412

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Returns the currently authenticated user's information
- User object attributes are configurable

---

### 10. Modify Current User

**Endpoint**: `POST /user/modify`

**Authentication Required**: Yes (Bearer token)

**Request Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "email": "string (optional)",
  "email_validated": "boolean (optional)",
  "first_name": "string (optional)",
  "last_name": "string (optional)",
  "username": "string (optional)",
  "verifier_token": "boolean (optional)"
}
```

**Field Types**:
- `email`: String (optional)
- `email_validated`: Boolean (optional) - Accepts: true, false, "true", "false", 1, 0, "1", "0"
- `first_name`: String (optional)
- `last_name`: String (optional)
- `username`: String (optional)
- `verifier_token`: Boolean (optional) - Accepts: true, false, "true", "false", 1, 0, "1", "0"

**Response** (201 Created):
```json
{
  "id": "integer",
  "username": "string",
  "email": "string",
  "first_name": "string",
  "last_name": "string",
  "email_validated": "boolean",
  "roles": "array",
  "created_at": "string",
  "verifier_token": "string",
  "last_known_timezone": "string"
}
```

**Response Schema**:
- Updated User object with configured default attributes

**Error Responses**:
- `400 Bad Request`: Invalid arguments (validation errors)
- `401 Unauthorized`: Missing or invalid token
- `500 Internal Server Error`: Server error

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Only include fields you want to update
- Setting `verifier_token: true` will reset the verifier token, invalidating all existing sessions (logout all devices)
- This is useful for security purposes (e.g., if account is compromised)

---

## Username Availability

### 11. Check Username Availability

**Endpoint**: `GET /username/available/:username`

**Authentication Required**: No

**URL Parameters**:
- `username`: String (required) - The username to check (in URL path)

**Request Headers**: None required

**Request Body**: None

**Response** (200 OK):
```json
{
  "username": {
    "available": "boolean",
    "valid": "boolean",
    "description": "string"
  }
}
```

**Response Schema**:
- `username`: Object (required)
  - `available`: Boolean (required) - Whether the username is available
  - `valid`: Boolean (required) - Whether the username passes validation rules
  - `description`: String (required) - Validation failure message if invalid, or success message

**Error Responses**:
- `400 Bad Request`: Invalid request parameters (e.g., missing or invalid username parameter)

**Notes**:
- This endpoint may only be available if realtime username checking is enabled in configuration
- Use this endpoint before attempting user registration to check username availability
- The endpoint checks both availability and validation rules

---

## Roles and Authorization (RBAC)

### Overview

CommandTower uses RBAC (Role-Based Access Control) to manage permissions. The system works by:
1. **Entities**: Define which controllers and actions require authorization
2. **Roles**: Group entities together and assign them to users
3. **Authorization Check**: When a user makes a request, the system checks if their roles grant access to the requested controller/action

### How Authorization Works

**Authorization Flow**:
1. User makes an authenticated request with a Bearer token
2. System authenticates the user (validates token)
3. System checks if the controller/action requires authorization
4. If authorization is required, system checks user's roles
5. System verifies if any of the user's roles grant access to the requested endpoint
6. If authorized, request proceeds; if not, returns `403 Forbidden`

**Key Concepts**:
- **Entities**: Map controllers and specific actions to authorization requirements
- **Roles**: Collections of entities that define what a user can access
- **Multiple Roles**: Users can have multiple roles; access is the union of all role permissions
- **Owner Role**: Special role that bypasses all authorization checks

### CommandTower Endpoints by Authorization Requirement

#### Quick Reference: Endpoint Access by Role

| Endpoint | Public | Authenticated | owner | admin | admin-without-impersonation | admin-read-only |
|----------|--------|---------------|-------|-------|----------------------------|-----------------|
| `POST /auth/create` | ✓ | - | ✓ | ✓ | ✓ | ✓ |
| `POST /auth/login` | ✓ | - | ✓ | ✓ | ✓ | ✓ |
| `GET /username/available/:username` | ✓ | - | ✓ | ✓ | ✓ | ✓ |
| `GET /user` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `POST /user/modify` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `GET /inbox/messages` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `GET /inbox/messages/:id` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `DELETE /inbox/messages/:id` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `POST /inbox/messages/ack` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `POST /inbox/messages/delete` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `POST /auth/email/send` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `POST /auth/email/verify` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `GET /admin` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `POST /admin/modify` | - | ✓ | ✓ | ✓ | ✓ | ✗ |
| `POST /admin/modify/role` | - | ✓ | ✓ | ✓ | ✓ | ✗ |
| `POST /admin/impersonate` | - | ✓ | ✓ | ✓ | ✗ | ✗ |
| `GET /inbox/blast` | - | ✓ | ✓ | ✓ | ✓ | ✓ (metadata only) |
| `GET /inbox/blast/:id` | - | ✓ | ✓ | ✓ | ✓ | ✗ |
| `POST /inbox/blast` | - | ✓ | ✓ | ✓ | ✓ | ✗ |
| `PATCH /inbox/blast/:id` | - | ✓ | ✓ | ✓ | ✓ | ✗ |
| `DELETE /inbox/blast/:id` | - | ✓ | ✓ | ✓ | ✓ | ✗ |

**Legend**:
- ✓ = Access granted
- ✗ = Access denied (403 Forbidden)
- - = Not applicable

#### Public Endpoints (No Authentication Required)
- `POST /auth/create` - User signup
- `POST /auth/login` - User login
- `GET /username/available/:username` - Check username availability

#### Authenticated Only (No Role Required)
These endpoints require authentication but no specific role:
- `GET /user` - Get current user
- `POST /user/modify` - Modify current user
- `GET /inbox/messages` - List messages
- `GET /inbox/messages/:id` - Get single message
- `DELETE /inbox/messages/:id` - Delete message
- `POST /inbox/messages/ack` - Acknowledge messages
- `POST /inbox/messages/delete` - Delete messages (bulk)
- `POST /auth/email/send` - Send email verification
- `POST /auth/email/verify` - Verify email

#### Admin-Only Endpoints (Require Admin Roles)
These endpoints require both authentication and appropriate admin roles:

**AdminController Endpoints**:
- `GET /admin` - List all users
- `POST /admin/modify` - Modify any user
- `POST /admin/modify/role` - Modify user roles
- `POST /admin/impersonate` - Impersonate user (if implemented)

**MessageBlastController Endpoints**:
- `GET /inbox/blast` - List message blasts
- `GET /inbox/blast/:id` - Get message blast
- `POST /inbox/blast` - Create message blast
- `PATCH /inbox/blast/:id` - Modify message blast
- `DELETE /inbox/blast/:id` - Delete message blast

### Default Roles

#### `owner`
- **Access**: Full access to ALL routes regardless of required roles
- **Bypasses**: All authorization checks
- **Use Case**: System owner/super admin
- **Entities**: `true` (allows everything)

#### `admin`
- **Access**:
  - All `AdminController` actions (including impersonate)
  - All `MessageBlastController` actions
- **Entities**:
  - `admin` (AdminController, all actions)
  - `message-blast` (MessageBlastController, all actions)
- **Endpoints**:
  - `GET /admin` ✓
  - `POST /admin/modify` ✓
  - `POST /admin/modify/role` ✓
  - `POST /admin/impersonate` ✓ (if implemented)
  - All message blast endpoints ✓

#### `admin-without-impersonation`
- **Access**:
  - All `AdminController` actions EXCEPT impersonate
  - All `MessageBlastController` actions
- **Entities**:
  - `admin-without-impersonate` (AdminController, except: impersonate)
  - `message-blast` (MessageBlastController, all actions)
- **Endpoints**:
  - `GET /admin` ✓
  - `POST /admin/modify` ✓
  - `POST /admin/modify/role` ✓
  - `POST /admin/impersonate` ✗ (blocked)
  - All message blast endpoints ✓

#### `admin-read-only`
- **Access**:
  - Read-only access to `AdminController` (show action only)
  - Read-only access to `MessageBlastController` (metadata only)
- **Entities**:
  - `read-admin` (AdminController, only: show)
  - `message-blast-read-only` (MessageBlastController, only: metadata)
- **Endpoints**:
  - `GET /admin` ✓
  - `POST /admin/modify` ✗ (blocked)
  - `POST /admin/modify/role` ✗ (blocked)
  - `GET /inbox/blast` ✓ (metadata only)
  - `GET /inbox/blast/:id` ✗ (blocked)
  - `POST /inbox/blast` ✗ (blocked)
  - `PATCH /inbox/blast/:id` ✗ (blocked)
  - `DELETE /inbox/blast/:id` ✗ (blocked)

### Role Assignment

Roles are assigned to users via the admin endpoint:
```json
POST /admin/modify/role
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "user_id": 123,
  "roles": ["admin"]
}
```

**Multiple Roles**: Users can have multiple roles. If a user has multiple roles, they get access to the union of all permissions from those roles.

**Example**:
```json
{
  "user_id": 123,
  "roles": ["admin", "moderator"]
}
```
The user will have access to all endpoints granted by either `admin` or `moderator` roles.

### Authorization Errors

When a user attempts to access an endpoint without the required role:
- **Status**: `403 Forbidden`
- **Response**:
```json
{
  "status": "403",
  "message": "Unauthorized Access. Incorrect User Privileges"
}
```

### Using RBAC with Custom Endpoints

CommandTower's RBAC system can be extended to protect your own custom controllers and endpoints outside of CommandTower. This allows you to use the same authorization system for your application's endpoints.

#### Step 1: Create Your Custom Controller

First, create your controller that inherits from `CommandTower::ApplicationController`:

```ruby
# app/controllers/api/v1/products_controller.rb
module Api
  module V1
    class ProductsController < CommandTower::ApplicationController
      include CommandTower::SchemaHelper

      before_action :authenticate_user!
      before_action :authorize_user!  # Add this to require authorization

      def index
        # List products
      end

      def show
        # Show single product
      end

      def create
        # Create product
      end

      def update
        # Update product
      end

      def destroy
        # Delete product
      end
    end
  end
end
```

#### Step 2: Define Entities

Entities map controllers to authorization requirements. Create a YAML configuration file at `config/rbac_groups.yml`:

```yaml
entities:
  # Define entities for your custom controllers
  - name: products-read
    controller: Api::V1::ProductsController
    only: [index, show]  # Only allow index and show actions

  - name: products-write
    controller: Api::V1::ProductsController
    only: [create, update, destroy]  # Only allow create, update, destroy

  - name: products-full
    controller: Api::V1::ProductsController
    # No 'only' or 'except' means all actions are included

  # Example: Exclude specific actions
  - name: products-no-delete
    controller: Api::V1::ProductsController
    except: [destroy]  # All actions except destroy
```

**Entity Options**:
- `name`: Unique identifier for the entity
- `controller`: Controller class name (string or constant)
- `only`: Array of action names (only these actions require authorization)
- `except`: Array of action names (all actions except these require authorization)
- If neither `only` nor `except` is specified, all controller actions require authorization

#### Step 3: Define Roles

Roles group entities together. Add roles to the same `config/rbac_groups.yml` file:

```yaml
groups:
  # Product Manager Role - Full access to products
  product-manager:
    description: "Full access to product management"
    entities:
      - products-full

  # Product Viewer Role - Read-only access
  product-viewer:
    description: "Read-only access to products"
    entities:
      - products-read

  # Product Editor Role - Can create/update but not delete
  product-editor:
    description: "Can create and update products but not delete"
    entities:
      - products-read
      - products-write

  # Example: Role with multiple entities
  content-manager:
    description: "Manages both products and articles"
    entities:
      - products-full
      - articles-full
```

**Role Options**:
- `description`: Human-readable description of the role
- `entities`: Array of entity names that this role grants access to
- `entities: true`: Special value that grants access to ALL endpoints (like `owner` role)

#### Step 4: Assign Roles to Users

Use the admin endpoint to assign roles:

```json
POST /admin/modify/role
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "user_id": 123,
  "roles": ["product-manager"]
}
```

#### Complete Example: Products API

**1. Controller** (`app/controllers/api/v1/products_controller.rb`):
```ruby
module Api
  module V1
    class ProductsController < CommandTower::ApplicationController
      before_action :authenticate_user!
      before_action :authorize_user!

      def index
        # Only users with products-read or products-full can access
        products = Product.all
        render json: products
      end

      def create
        # Only users with products-write or products-full can access
        product = Product.create(product_params)
        render json: product, status: :created
      end
    end
  end
end
```

**2. RBAC Configuration** (`config/rbac_groups.yml`):
```yaml
entities:
  - name: products-read
    controller: Api::V1::ProductsController
    only: [index, show]

  - name: products-write
    controller: Api::V1::ProductsController
    only: [create, update, destroy]

  - name: products-full
    controller: Api::V1::ProductsController

groups:
  product-manager:
    description: "Full product management access"
    entities:
      - products-full

  product-viewer:
    description: "Read-only product access"
    entities:
      - products-read

  product-editor:
    description: "Can create and update products"
    entities:
      - products-read
      - products-write
```

**3. Assign Role**:
```json
POST /admin/modify/role
{
  "user_id": 456,
  "roles": ["product-manager"]
}
```

**4. Access Control**:
- User with `product-manager` role: Can access all product endpoints
- User with `product-viewer` role: Can only access `index` and `show`
- User with `product-editor` role: Can access `index`, `show`, `create`, `update`, `destroy` (but not delete if you create a separate entity for that)

#### Advanced: Custom Entity Authorization

For more complex authorization logic, you can create custom entity classes that override the `authorized?` method:

```ruby
# app/models/authorization/product_entity.rb
class ProductEntity < CommandTower::Authorization::Entity
  def authorized?(user:)
    # Custom logic: Only allow if user's email is validated
    return false unless user.email_validated

    # Additional custom checks
    user.active? && user.organization_id == product.organization_id
  end
end
```

Then use it in your YAML:
```yaml
entities:
  - name: products-custom
    controller: Api::V1::ProductsController
    entity_class: ProductEntity  # Use custom entity class
```

#### Configuration

The RBAC configuration file path can be customized in your CommandTower initializer:

```ruby
# config/initializers/command_tower.rb
CommandTower.configure do |c|
  c.authorization.rbac_group_path = Rails.root.join("config", "custom_rbac.yml")
end
```

**Default Path**: `config/rbac_groups.yml`

#### Best Practices

1. **Use Descriptive Names**: Entity and role names should clearly indicate their purpose
2. **Principle of Least Privilege**: Grant minimum necessary permissions
3. **Group Related Actions**: Use `only` or `except` to group related actions
4. **Document Roles**: Use clear descriptions in your YAML configuration
5. **Test Authorization**: Always test that authorization works as expected
6. **Multiple Roles**: Users can have multiple roles; design roles to work well together

#### Troubleshooting

**Authorization Not Working**:
- Ensure `before_action :authorize_user!` is called after `authenticate_user!`
- Verify the controller class name in YAML matches exactly (including namespace)
- Check that entity names in roles match entity names in entities section
- Ensure roles are assigned to users via `/admin/modify/role`

**Controller Not Found Error**:
- Ensure controller is loaded before RBAC configuration is loaded
- Verify controller class name is correct (use full namespace: `Api::V1::ProductsController`)

**Actions Not Protected**:
- Verify entity definition includes the action in `only` or excludes it in `except`
- Check that `before_action :authorize_user!` is present in controller

---

## Admin Endpoints

All admin endpoints require:
1. **Authentication**: Valid Bearer token
2. **Authorization**: User must have appropriate admin role

**Default Admin Roles**:
- `owner`: Full access to all routes (bypasses all authorization checks)
- `admin`: Full access to all AdminController actions including impersonation
- `admin-without-impersonation`: Full admin access except impersonation
- `admin-read-only`: Can only view users (GET /admin)

**Authorization Failure**: Returns `403 Forbidden` if user lacks required permissions.

---

### 12. List All Users (Admin)

**Endpoint**: `GET /admin`

**Authentication Required**: Yes (Bearer token with admin role)

**Request Headers**:
```
Authorization: Bearer {token}
```

**Query Parameters** (Pagination - Optional):
- `pagination=true` (String, required to enable pagination)
- `limit=<integer>` (Integer, optional, defaults to configured default, typically 10)
- `page=<integer>` (Integer, optional, page number starting from 1)
- `cursor=<integer>` (Integer, optional, takes precedence over page)

**Request Body**: None

**Response** (200 OK):
```json
{
  "users": [
    {
      "id": "integer",
      "username": "string",
      "email": "string",
      "first_name": "string",
      "last_name": "string",
      "email_validated": "boolean",
      "roles": "array",
      "created_at": "string",
      "verifier_token": "string",
      "last_known_timezone": "string"
    }
  ],
  "count": "integer",
  "pagination": {
    "current": {
      "cursor": "integer",
      "limit": "integer",
      "query": "string"
    },
    "next": {
      "cursor": "integer",
      "limit": "integer",
      "query": "string"
    },
    "count_available": "integer",
    "current_page": "integer",
    "remaining_pages": "integer",
    "total_pages": "integer"
  }
}
```

**Response Schema**:
- `users`: Array (required) - Array of User objects with configured default attributes
- `count`: Integer (optional) - Total count of users
- `pagination`: Object (optional) - Pagination metadata:
  - `current`: Object (required) - Current page information:
    - `cursor`: Integer (required) - Current cursor position
    - `limit`: Integer (required) - Current page limit
    - `query`: String (required) - Query identifier
  - `next`: Object (optional) - Next page information (same structure as current)
  - `count_available`: Integer (optional) - Number of records available
  - `current_page`: Integer (optional) - Current page number
  - `remaining_pages`: Integer (optional) - Number of pages remaining
  - `total_pages`: Integer (optional) - Total number of pages

**Error Responses**:
- `401 Unauthorized`: Missing or invalid token
- `403 Forbidden`: User does not have admin permissions

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Pagination is optional but recommended for large user lists
- Default pagination limit is typically 10 (configurable)
- Use `cursor` for cursor-based pagination (recommended for large datasets)
- Use `page` for page-based pagination
- `cursor` takes precedence over `page` if both are provided
- Example: `GET /admin?pagination=true&limit=50&page=1`

---

### 13. Modify User (Admin)

**Endpoint**: `POST /admin/modify`

**Authentication Required**: Yes (Bearer token with admin role)

**Request Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "user_id": "integer",
  "email": "string (optional)",
  "email_validated": "boolean (optional)",
  "first_name": "string (optional)",
  "last_name": "string (optional)",
  "username": "string (optional)",
  "verifier_token": "boolean (optional)"
}
```

**Field Types**:
- `user_id`: Integer (required) - ID of the user to modify
- `email`: String (optional)
- `email_validated`: Boolean (optional) - Accepts: true, false, "true", "false", 1, 0, "1", "0"
- `first_name`: String (optional)
- `last_name`: String (optional)
- `username`: String (optional)
- `verifier_token`: Boolean (optional) - Accepts: true, false, "true", "false", 1, 0, "1", "0"

**Response** (201 Created):
```json
{
  "id": "integer",
  "username": "string",
  "email": "string",
  "first_name": "string",
  "last_name": "string",
  "email_validated": "boolean",
  "roles": "array",
  "created_at": "string",
  "verifier_token": "string",
  "last_known_timezone": "string"
}
```

**Response Schema**:
- Updated User object with configured default attributes

**Error Responses**:
- `400 Bad Request`: Invalid arguments (validation errors, including invalid user_id)
- `401 Unauthorized`: Missing or invalid token
- `403 Forbidden`: User does not have admin permissions
- `500 Internal Server Error`: Server error

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Admins can modify any user's attributes
- Setting `verifier_token: true` will reset the user's verifier token, logging them out of all sessions
- This is useful for security purposes (e.g., if user's account is compromised)

---

### 14. Modify User Roles (Admin)

**Endpoint**: `POST /admin/modify/role`

**Authentication Required**: Yes (Bearer token with admin role)

**Request Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "user_id": "integer",
  "roles": ["array", "of", "role", "strings"]
}
```

**Field Types**:
- `user_id`: Integer (required) - ID of the user to modify
- `roles`: Array (optional, defaults to empty array) - Array of role strings

**Response** (201 Created):
```json
{
  "id": "integer",
  "username": "string",
  "email": "string",
  "first_name": "string",
  "last_name": "string",
  "email_validated": "boolean",
  "roles": "array",
  "created_at": "string",
  "verifier_token": "string",
  "last_known_timezone": "string"
}
```

**Response Schema**:
- Updated User object with configured default attributes including roles

**Error Responses**:
- `400 Bad Request`: Invalid arguments (validation errors, including invalid user_id)
- `401 Unauthorized`: Missing or invalid token
- `403 Forbidden`: User does not have admin permissions
- `500 Internal Server Error`: Server error

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Admins can assign roles to users
- Roles control access to various endpoints
- Valid roles are defined in the RBAC configuration
- Passing an empty array or omitting `roles` will remove all roles from the user
- Example roles: `["admin"]`, `["admin", "moderator"]`, `[]` (removes all roles)

---

## Inbox Endpoints

All inbox endpoints require authentication (Bearer token).

---

### 15. Get Messages Metadata

**Endpoint**: `GET /inbox/messages`

**Authentication Required**: Yes (Bearer token)

**Request Headers**:
```
Authorization: Bearer {token}
```

**Query Parameters** (Pagination - Optional):
- `pagination=true` (String, required to enable pagination)
- `limit=<integer>` (Integer, optional)
- `page=<integer>` (Integer, optional)
- `cursor=<integer>` (Integer, optional, takes precedence over page)

**Request Body**: None

**Response** (200 OK):
```json
{
  "entities": [
    {
      "id": "integer",
      "title": "string",
      "text": "string",
      "viewed": "boolean"
    }
  ],
  "count": "integer",
  "pagination": {
    "current": {
      "cursor": "integer",
      "limit": "integer",
      "query": "string"
    },
    "next": {
      "cursor": "integer",
      "limit": "integer",
      "query": "string"
    },
    "count_available": "integer",
    "current_page": "integer",
    "remaining_pages": "integer",
    "total_pages": "integer"
  }
}
```

**Response Schema**:
- `entities`: Array (optional) - Array of MessageEntity objects:
  - `id`: Integer (required) - Message ID
  - `title`: String (required) - Message title
  - `text`: String (optional) - Message text content
  - `viewed`: Boolean (required) - Whether message has been viewed
- `count`: Integer (required) - Total count of messages
- `pagination`: Object (optional) - Pagination metadata (same structure as admin list)

**Error Responses**:
- `400 Bad Request`: Invalid arguments (pagination errors)
- `401 Unauthorized`: Missing or invalid token

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Returns messages for the authenticated user
- Pagination is optional but recommended for large message lists

---

### 13. Get Single Message

**Endpoint**: `GET /inbox/messages/:id`

**Authentication Required**: Yes (Bearer token)

**Request Headers**:
```
Authorization: Bearer {token}
```

**URL Parameters**:
- `id`: Integer (required) - Message ID

**Request Body**: None

**Response** (200 OK):
```json
{
  "id": "integer",
  "title": "string",
  "text": "string",
  "viewed": "boolean"
}
```

**Response Schema**:
- `id`: Integer (required) - Message ID
- `title`: String (required) - Message title
- `text`: String (optional) - Message text content
- `viewed`: Boolean (required) - Whether message has been viewed

**Error Responses**:
- `400 Bad Request`: Invalid arguments (invalid message ID or access denied)
- `401 Unauthorized`: Missing or invalid token

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Returns a single message by ID
- User can only access their own messages

---

### 14. Delete Message by ID

**Endpoint**: `DELETE /inbox/messages/:id`

**Authentication Required**: Yes (Bearer token)

**Request Headers**:
```
Authorization: Bearer {token}
```

**URL Parameters**:
- `id`: Integer (required) - Message ID

**Request Body**: None

**Response** (200 OK):
```json
{
  "type": "symbol",
  "ids": ["array", "of", "integers"],
  "count": "integer"
}
```

**Response Schema**:
- `type`: Symbol (required) - Type of modification (e.g., "delete")
- `ids`: Array (required) - Array of message IDs that were deleted
- `count`: Integer (required) - Number of messages deleted

**Error Responses**:
- `400 Bad Request`: Invalid arguments
- `401 Unauthorized`: Missing or invalid token

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Deletes a single message by ID
- User can only delete their own messages

---

### 15. Acknowledge Messages (Mark as Viewed)

**Endpoint**: `POST /inbox/messages/ack`

**Authentication Required**: Yes (Bearer token)

**Request Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "ids": ["array", "of", "integers"]
}
```

**Field Types**:
- `ids`: Array (required) - Array of message IDs (integers) to mark as viewed

**Response** (200 OK):
```json
{
  "type": "symbol",
  "ids": ["array", "of", "integers"],
  "count": "integer"
}
```

**Response Schema**:
- `type`: Symbol (required) - Type of modification (e.g., "viewed")
- `ids`: Array (required) - Array of message IDs that were acknowledged
- `count`: Integer (required) - Number of messages acknowledged

**Error Responses**:
- `400 Bad Request`: Invalid arguments (invalid IDs or validation errors)
- `401 Unauthorized`: Missing or invalid token

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Marks multiple messages as viewed/acknowledged
- `ids` must be an array of message IDs
- Example: `{ "ids": [1, 2, 3] }`

---

### 16. Delete Messages (Bulk)

**Endpoint**: `POST /inbox/messages/delete`

**Authentication Required**: Yes (Bearer token)

**Request Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "ids": ["array", "of", "integers"]
}
```

**Field Types**:
- `ids`: Array (required) - Array of message IDs (integers) to delete

**Response** (200 OK):
```json
{
  "type": "symbol",
  "ids": ["array", "of", "integers"],
  "count": "integer"
}
```

**Response Schema**:
- `type`: Symbol (required) - Type of modification (e.g., "delete")
- `ids`: Array (required) - Array of message IDs that were deleted
- `count`: Integer (required) - Number of messages deleted

**Error Responses**:
- `400 Bad Request`: Invalid arguments (invalid IDs or validation errors)
- `401 Unauthorized`: Missing or invalid token

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Deletes multiple messages at once
- `ids` must be an array of message IDs
- Example: `{ "ids": [1, 2, 3] }`

---

### 17. Get Message Blast Metadata

**Endpoint**: `GET /inbox/blast`

**Authentication Required**: Yes (Bearer token with admin role)

**Request Headers**:
```
Authorization: Bearer {token}
```

**Request Body**: None

**Response** (200 OK):
```json
{
  "entities": [
    {
      "id": "integer",
      "title": "string",
      "text": "string",
      "existing_users": "boolean",
      "new_users": "boolean",
      "created_by": {
        "id": "integer",
        "username": "string",
        "email": "string"
      }
    }
  ],
  "count": "integer",
  "pagination": {
    "current": {
      "cursor": "integer",
      "limit": "integer",
      "query": "string"
    },
    "next": {
      "cursor": "integer",
      "limit": "integer",
      "query": "string"
    },
    "count_available": "integer",
    "current_page": "integer",
    "remaining_pages": "integer",
    "total_pages": "integer"
  }
}
```

**Response Schema**:
- `entities`: Array (optional) - Array of MessageBlastEntity objects:
  - `id`: Integer (required) - Message blast ID
  - `title`: String (required) - Message blast title
  - `text`: String (optional) - Message blast text content
  - `existing_users`: Boolean (required) - Whether sent to existing users
  - `new_users`: Boolean (required) - Whether sent to new users
  - `created_by`: Object (optional) - User object of creator (may be omitted for performance)
- `count`: Integer (required) - Total count of message blasts
- `pagination`: Object (optional) - Pagination metadata (same structure as other endpoints)

**Error Responses**:
- `401 Unauthorized`: Missing or invalid token
- `403 Forbidden`: User does not have required permissions

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Requires admin authorization
- Returns metadata about message blasts

---

### 18. Get Single Message Blast

**Endpoint**: `GET /inbox/blast/:id`

**Authentication Required**: Yes (Bearer token with admin role)

**Request Headers**:
```
Authorization: Bearer {token}
```

**URL Parameters**:
- `id`: Integer (required) - Message Blast ID

**Request Body**: None

**Response** (200 OK):
```json
{
  "id": "integer",
  "title": "string",
  "text": "string",
  "existing_users": "boolean",
  "new_users": "boolean",
  "created_by": {
    "id": "integer",
    "username": "string",
    "email": "string",
    "first_name": "string",
    "last_name": "string"
  }
}
```

**Response Schema**:
- `id`: Integer (required) - Message blast ID
- `title`: String (required) - Message blast title
- `text`: String (optional) - Message blast text content
- `existing_users`: Boolean (required) - Whether sent to existing users
- `new_users`: Boolean (required) - Whether sent to new users
- `created_by`: Object (optional) - User object of creator with configured default attributes

**Error Responses**:
- `400 Bad Request`: Invalid arguments (invalid ID)
- `401 Unauthorized`: Missing or invalid token
- `403 Forbidden`: User does not have required permissions

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

---

### 19. Create Message Blast

**Endpoint**: `POST /inbox/blast`

**Authentication Required**: Yes (Bearer token with admin role)

**Request Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body Schema**:
```json
{
  "existing_users": "boolean",
  "new_users": "boolean",
  "title": "string",
  "text": "string",
  "id": "integer"
}
```

**Field Types**:
- `existing_users`: Boolean (required) - Accepts: true, false, "true", "false", 1, 0, "1", "0"
- `new_users`: Boolean (required) - Accepts: true, false, "true", "false", 1, 0, "1", "0"
- `title`: String (required) - Message blast title
- `text`: String (required) - Message blast text content
- `id`: Integer (optional) - Message blast ID (for updates)

**Response** (200 OK):
```json
{
  "id": "integer",
  "title": "string",
  "text": "string",
  "existing_users": "boolean",
  "new_users": "boolean",
  "created_by": {
    "id": "integer",
    "username": "string",
    "email": "string",
    "first_name": "string",
    "last_name": "string"
  }
}
}
```

**Response Schema**:
- `id`: Integer (optional) - Message blast ID
- `title`: String (required) - Message blast title
- `text`: String (required) - Message blast text content
- `existing_users`: Boolean (required) - Whether sent to existing users
- `new_users`: Boolean (required) - Whether sent to new users
- `created_by`: Object (required) - User object of creator with configured default attributes

**Error Responses**:
- `400 Bad Request`: Invalid arguments (validation errors)
- `401 Unauthorized`: Missing or invalid token
- `403 Forbidden`: User does not have required permissions

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

**Notes**:
- Creates a message blast that can be sent to existing users, new users, or both
- `existing_users` and `new_users` are boolean flags
- The creator is automatically set to the authenticated admin user

---

### 20. Modify Message Blast

**Endpoint**: `PATCH /inbox/blast/:id`

**Authentication Required**: Yes (Bearer token with admin role)

**Request Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**URL Parameters**:
- `id`: Integer (required) - Message Blast ID

**Request Body Schema**:
```json
{
  "existing_users": "boolean",
  "new_users": "boolean",
  "title": "string",
  "text": "string"
}
```

**Field Types**:
- `existing_users`: Boolean (required) - Accepts: true, false, "true", "false", 1, 0, "1", "0"
- `new_users`: Boolean (required) - Accepts: true, false, "true", "false", 1, 0, "1", "0"
- `title`: String (required) - Message blast title
- `text`: String (required) - Message blast text content

**Response** (200 OK):
```json
{
  "id": "integer",
  "title": "string",
  "text": "string",
  "existing_users": "boolean",
  "new_users": "boolean",
  "created_by": {
    "id": "integer",
    "username": "string",
    "email": "string",
    "first_name": "string",
    "last_name": "string"
  }
}
```

**Response Schema**:
- Same as Create Message Blast response

**Error Responses**:
- `400 Bad Request`: Invalid arguments (validation errors)
- `401 Unauthorized`: Missing or invalid token
- `403 Forbidden`: User does not have required permissions

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

---

### 21. Delete Message Blast

**Endpoint**: `DELETE /inbox/blast/:id`

**Authentication Required**: Yes (Bearer token with admin role)

**Request Headers**:
```
Authorization: Bearer {token}
```

**URL Parameters**:
- `id`: Integer (required) - Message Blast ID

**Request Body**: None

**Response** (200 OK):
```json
{
  "id": "integer",
  "msg": "string"
}
```

**Response Schema**:
- `id`: Integer (required) - Deleted message blast ID
- `msg`: String (required) - "Message Blast message deleted"

**Error Responses**:
- `400 Bad Request`: Invalid arguments (invalid ID)
- `401 Unauthorized`: Missing or invalid token
- `403 Forbidden`: User does not have required permissions

**Response Headers**:
- `X-Authorization-Expire`: Token expiration timestamp

---

## Complete Workflows

### Signup Workflow

**Step 1: Check Username Availability** (Optional)
```
GET /username/available/:username
```
- Verify username is available before signup
- Response indicates if username is available and valid

**Step 2: Create Account**
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
- Response includes user details (no token yet)
- Status: 201 Created

**Step 3: Login**
```
POST /auth/login
Content-Type: application/json

{
  "identifier": "johndoe",
  "password": "securepassword123"
}
```
- Use `identifier` (can be username or email) with `password`
- Response includes JWT `token` and user object
- Status: 201 Created

**Step 4: Email Verification** (If enabled)
```
POST /auth/email/send
Authorization: Bearer {token}
```
- Request verification code
- Code is sent to user's email
- Status: 201 Created

```
POST /auth/email/verify
Authorization: Bearer {token}
Content-Type: application/json

{
  "code": "verification_code_from_email"
}
```
- Verify with code from email
- Email is marked as validated
- Status: 201 Created

**Step 5: Access Protected Endpoints**
- Use `Authorization: Bearer {token}` header for all subsequent requests
- Monitor `X-Authorization-Expire` header for token expiration

---

### Login Workflow

**Step 1: Login**
```
POST /auth/login
Content-Type: application/json

{
  "identifier": "user@example.com",
  "password": "password123"
}
```
- Use `identifier` (can be username or email) with `password`
- Response includes JWT `token` and user object
- Status: 201 Created

**Step 2: Store Token**
- Save the `token` value from response
- Use in `Authorization: Bearer {token}` header for all authenticated requests

**Step 3: Monitor Token Expiration**
- Check `X-Authorization-Expire` header on each response
- Parse timestamp and calculate time until expiration
- Refresh token before expiration if needed

**Step 4: Refresh Token** (When Needed)
```
GET /user
Authorization: Bearer {old_token}
X-Authorization-Reset: true
```
- Include `X-Authorization-Reset: true` header in any authenticated request
- Response will include new token in `X-Authorization-Reset` header
- Update stored token with new value
- Use new token for all subsequent requests

**Example Token Refresh Flow**:
1. Client makes request with `X-Authorization-Reset: true`
2. Server processes request and generates new token
3. Server returns response with:
   - `X-Authorization-Reset: {new_token}` header
   - `X-Authorization-Expire: {new_expiration}` header
   - Normal response body
4. Client extracts new token from `X-Authorization-Reset` header
5. Client replaces stored token with new token
6. Client uses new token for all future requests

---

### Admin Workflow

**Step 1: Login as Admin**
```
POST /auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "adminpassword"
}
```
- Receive JWT token
- User must have admin role

**Step 2: List Users**
```
GET /admin?pagination=true&limit=50&page=1
Authorization: Bearer {token}
```
- Query params: `pagination=true&limit=50&page=1`
- Review user list with pagination
- Status: 200 OK

**Step 3: Modify User**
```
POST /admin/modify
Authorization: Bearer {token}
Content-Type: application/json

{
  "user_id": 123,
  "email": "newemail@example.com",
  "first_name": "Updated"
}
```
- Update user attributes
- Status: 201 Created

**Step 4: Modify User Roles**
```
POST /admin/modify/role
Authorization: Bearer {token}
Content-Type: application/json

{
  "user_id": 123,
  "roles": ["admin"]
}
```
- Assign or update user roles
- Status: 201 Created

**Step 5: Create Message Blast**
```
POST /inbox/blast
Authorization: Bearer {token}
Content-Type: application/json

{
  "existing_users": true,
  "new_users": false,
  "title": "Important Announcement",
  "text": "This is an important message for all existing users."
}
```
- Send messages to users
- Status: 200 OK

---

### Email Verification Workflow

**Step 1: User Logs In**
```
POST /auth/login
Content-Type: application/json

{
  "username": "user",
  "password": "password"
}
```
- Receive token
- Status: 201 Created

**Step 2: Request Verification Code**
```
POST /auth/email/send
Authorization: Bearer {token}
```
- Code is sent to user's email
- Status: 201 Created

**Step 3: Verify Email**
```
POST /auth/email/verify
Authorization: Bearer {token}
Content-Type: application/json

{
  "code": "code_from_email"
}
```
- Email is marked as validated
- `email_validated` flag is set to `true`
- Status: 201 Created

**Step 4: Access Full Features**
- User can now access all protected endpoints
- No more email verification restrictions

---

## Error Handling

### Error Response Format

All error responses follow a standard format:

**Base Error Schema**:
```json
{
  "status": "string",
  "message": "string"
}
```

**Field Types**:
- `status`: String (required) - HTTP status code as string (e.g., "401", "403", "400")
- `message`: String (required) - Human-readable error message

**Invalid Arguments Error Schema** (for validation errors):
```json
{
  "status": "string",
  "message": "string",
  "invalid_arguments": [
    {
      "schema": "object",
      "argument": "string",
      "argument_type": "string",
      "reason": "string"
    }
  ],
  "invalid_argument_keys": ["array", "of", "strings"]
}
```

**Field Types**:
- `status`: String (required) - HTTP status code as string
- `message`: String (required) - Human-readable error message
- `invalid_arguments`: Array (optional) - Array of InvalidArgument objects:
  - `schema`: Object (required) - Schema definition
  - `argument`: String (required) - Field name that failed validation
  - `argument_type`: String (required) - Expected type
  - `reason`: String (optional) - Reason for validation failure
- `invalid_argument_keys`: Array (optional) - Array of field names that failed validation

### HTTP Status Codes

- **200 OK**: Request successful
- **201 Created**: Resource created successfully
- **400 Bad Request**: Invalid request format or validation errors
- **401 Unauthorized**: Authentication failure (missing/invalid token, invalid credentials)
- **403 Forbidden**: Authorization failure (insufficient permissions)
- **500 Internal Server Error**: Server error

### Common Error Scenarios

**1. Missing Authentication Token**
```
Status: 401 Unauthorized
Response: {
  "status": "401",
  "message": "Bearer token missing"
}
```

**2. Invalid Token Format**
```
Status: 401 Unauthorized
Response: {
  "status": "401",
  "message": "Invalid Bearer token format"
}
```

**3. Expired Token**
```
Status: 401 Unauthorized
Response: {
  "status": "401",
  "message": "Unauthorized Access. Invalid Authorization token"
}
```

**4. Invalid Verifier Token**
```
Status: 401 Unauthorized
Response: {
  "status": "401",
  "message": "Unauthorized Access. Token is no longer valid"
}
```

**5. Email Verification Required**
```
Status: 412 Precondition Failed
Response: {
  "status": "412",
  "message": "Email must be verified to continue",
  "meta": {
    "email_validated": false
  }
}
```

**6. Insufficient Permissions**
```
Status: 403 Forbidden
Response: {
  "status": "403",
  "message": "User does not have required permissions"
}
```

**7. Validation Errors**
```
Status: 400 Bad Request
Response: {
  "status": "400",
  "message": "Invalid arguments provided",
  "invalid_arguments": [
    {
      "schema": {...},
      "argument": "email",
      "argument_type": "String",
      "reason": "Email format is invalid"
    }
  ],
  "invalid_argument_keys": ["email"]
}
```

**8. Invalid User ID (Admin Endpoints)**
```
Status: 400 Bad Request
Response: {
  "status": "400",
  "message": "Invalid user"
}
```

### Error Handling Best Practices

1. **Always Check Status Codes**: Don't assume success based on response body alone
2. **Parse Error Messages**: Display user-friendly error messages to end users
3. **Handle Invalid Arguments**: Check `invalid_arguments` array for field-specific errors
4. **Token Expiration**: Monitor `X-Authorization-Expire` and refresh before expiration
5. **Retry Logic**: Implement retry logic for 401 errors (after refreshing token)
6. **Logging**: Log error responses for debugging (but never log tokens)

---

## Configuration Dependencies

Some endpoints may only be available based on configuration:

1. **Username Availability Endpoint** (`GET /username/available/:username`)
   - Requires `CommandTower.config.username.realtime_username_check` to be enabled
   - If disabled, this endpoint may not be available

2. **Email Verification Endpoints** (`POST /auth/email/send`, `POST /auth/email/verify`)
   - Require `CommandTower.config.login.plain_text.email_verify` to be enabled
   - If disabled, these endpoints may not be available

3. **Plain Text Authentication Endpoints** (`POST /auth/login`, `POST /auth/create`)
   - Require `CommandTower.config.login.plain_text.enable` to be enabled
   - If disabled, these endpoints may not be available

4. **User Attributes**
   - User object attributes returned are configurable via `CommandTower.config.user.default_attributes`
   - Default attributes typically include: `id`, `email`, `first_name`, `last_name`, `username`, `email_validated`, `roles`, `created_at`, `verifier_token`, `last_known_timezone`
   - Additional attributes can be configured

---

## Pagination

### Pagination Parameters

Pagination is available on list endpoints when explicitly enabled.

**Query Parameters**:
- `pagination=true` (String, required) - Must be set to enable pagination
- `limit` (Integer, optional) - Number of records per page (defaults to configured default, typically 10)
- `page` (Integer, optional) - Page number starting from 1
- `cursor` (Integer, optional) - Cursor position (takes precedence over page)

**Example**:
```
GET /admin?pagination=true&limit=50&page=2
GET /admin?pagination=true&limit=50&cursor=100
```

### Pagination Response Schema

```json
{
  "pagination": {
    "current": {
      "cursor": "integer",
      "limit": "integer",
      "query": "string"
    },
    "next": {
      "cursor": "integer",
      "limit": "integer",
      "query": "string"
    },
    "count_available": "integer",
    "current_page": "integer",
    "remaining_pages": "integer",
    "total_pages": "integer"
  }
}
```

**Field Types**:
- `current`: Object (required) - Current page information
  - `cursor`: Integer (required) - Current cursor position
  - `limit`: Integer (required) - Current page limit
  - `query`: String (required) - Query identifier
- `next`: Object (optional) - Next page information (same structure, null if no next page)
- `count_available`: Integer (optional) - Number of records available
- `current_page`: Integer (optional) - Current page number (1-based)
- `remaining_pages`: Integer (optional) - Number of pages remaining
- `total_pages`: Integer (optional) - Total number of pages

### Pagination Best Practices

1. **Use Cursor-Based Pagination**: Recommended for large datasets
2. **Set Appropriate Limits**: Balance between performance and user experience
3. **Check for Next Page**: Use `next` object to determine if more pages exist
4. **Default Limit**: Default is typically 10 (configurable)

---

## Additional Notes

### User Object Attributes

The User object returned in various endpoints includes attributes based on configuration. Common attributes include:

- `id`: Integer - User ID
- `username`: String - Username
- `email`: String - Email address
- `first_name`: String - First name
- `last_name`: String - Last name
- `email_validated`: Boolean - Whether email is verified
- `roles`: Array - User roles
- `created_at`: String/Timestamp - Account creation timestamp
- `verifier_token`: String - Token for session invalidation
- `last_known_timezone`: String - User's timezone

Additional attributes may be included based on `CommandTower.config.user.default_attributes` configuration.

### Token Refresh Best Practices

1. **Refresh Before Expiration**: Monitor `X-Authorization-Expire` and refresh when less than 5 minutes remain
2. **After Authenticated Password Change**: `POST /auth/password/change` invalidates all JWTs via verifier rotation and does **not** re-issue a token — clear local auth and Sign In again (refresh will fail)
3. **Refresh After Role Changes**: Refresh token after admin modifies user roles
4. **Don't Refresh Every Request**: Only refresh when necessary to avoid unnecessary latency
5. **Handle Refresh Failures**: Implement fallback logic if token refresh fails

### Security Considerations

1. **HTTPS Only**: Always use HTTPS in production environments
2. **Token Storage**: Store tokens securely (secure HTTP-only cookies, secure storage on mobile)
3. **Token Transmission**: Never expose tokens in URLs or logs
4. **Token Expiration**: Respect token expiration and refresh appropriately
5. **Verifier Token Reset**: Use verifier token reset to invalidate all sessions when needed
6. **Password Security**: Enforce strong password policies
7. **Email Verification**: Enable email verification for production environments

---

## Summary

This API reference provides comprehensive documentation for all CommandTower endpoints, including:

- Complete request/response schemas with field types
- Authentication and token management (including token refresh)
- User management workflows
- Admin functionality
- Inbox messaging system
- Error handling
- Pagination
- Configuration dependencies

For implementation details, refer to the integration tests in `/spec/integration_test/` and the service implementations in `/app/services/command_tower/`.
