# Email Verification Workflow

## Table of Contents

1. [Overview](#overview)
2. [Workflow Diagram](#workflow-diagram)
3. [Key Concepts](#key-concepts)
4. [Authentication Requirements](#authentication-requirements)
5. [Verification Method](#verification-method)
6. [Grace Period Behavior](#grace-period-behavior)
7. [Backend Implementation](#backend-implementation)
8. [Configuration Options](#configuration-options)
9. [API Endpoints](#api-endpoints)
10. [Error Handling](#error-handling)
11. [Security Considerations](#security-considerations)
12. [Complete User Journey](#complete-user-journey)

---

## Overview

Email verification in CommandTower is a **code-based verification system** that ensures users have access to the email address they registered with. This system provides a grace period during which users can access the API before verification is required, allowing for a smooth onboarding experience while maintaining security.

### Key Characteristics

- **Verification Method**: 6-digit numeric code (configurable length)
- **Code Delivery**: Sent via email to the user's registered email address
- **Code Expiration**: 10 minutes by default (configurable)
- **Authentication Required**: Users must be logged in (have a valid JWT token) to request or verify codes
- **Grace Period**: Configurable time window before verification becomes mandatory
- **RBAC Access**: During grace period, users have full API access based on their assigned roles

---

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    EMAIL VERIFICATION WORKFLOW                  │
└─────────────────────────────────────────────────────────────────┘

1. USER REGISTRATION
   ┌──────────────┐
   │ User Registers│
   │ POST /auth/   │
   │ create        │
   └──────┬───────┘
          │
          ▼
   ┌──────────────────────┐
   │ Account Created      │
   │ email_validated =    │
   │ false                │
   │ created_at = now     │
   └──────┬───────────────┘
          │
          ▼
2. USER LOGIN
   ┌──────────────┐
   │ User Logs In │
   │ POST /auth/  │
   │ login        │
   └──────┬───────┘
          │
          ▼
   ┌──────────────────────┐
   │ Receives JWT Token   │
   │ Token contains:      │
   │ - user_id            │
   │ - verifier_token     │
   │ - generated_at       │
   └──────┬───────────────┘
          │
          ▼
3. GRACE PERIOD ACTIVE
   ┌──────────────────────┐
   │ Grace Period Window  │
   │ (configurable)       │
   │                      │
   │ User can access API  │
   │ based on RBAC roles │
   │ Email check bypassed │
   └──────┬───────────────┘
          │
          ▼
4. REQUEST VERIFICATION CODE
   ┌──────────────────────┐
   │ User Requests Code   │
   │ POST /auth/email/send│
   │ [AUTH REQUIRED]      │
   └──────┬───────────────┘
          │
          ▼
5. CODE GENERATION & STORAGE
   ┌──────────────────────┐
   │ System Generates     │
   │ 6-Digit Code         │
   │                      │
   │ Stored in:           │
   │ - user_secrets table │
   │ - secret field       │
   │ - death_time set     │
   │   (expiration)       │
   └──────┬───────────────┘
          │
          ▼
6. EMAIL DELIVERY
   ┌──────────────────────┐
   │ Email Sent via        │
   │ ActiveMailer         │
   │                      │
   │ Contains:             │
   │ - 6-digit code        │
   │ - Expiration time     │
   └──────┬───────────────┘
          │
          ▼
7. USER SUBMITS CODE
   ┌──────────────────────┐
   │ User Enters Code     │
   │ POST /auth/email/    │
   │ verify               │
   │ [AUTH REQUIRED]      │
   │ Body: { code: "..." }│
   └──────┬───────────────┘
          │
          ▼
8. CODE VALIDATION
   ┌──────────────────────┐
   │ System Validates:    │
   │ - Code exists         │
   │ - Code not expired    │
   │ - Code matches user   │
   │ - Code not used       │
   └──────┬───────────────┘
          │
    ┌─────┴─────┐
    │           │
    ▼           ▼
┌─────────┐  ┌──────────────┐
│ Valid   │  │ Invalid/     │
│         │  │ Expired      │
└────┬────┘  └──────┬───────┘
     │              │
     │              ▼
     │      ┌──────────────┐
     │      │ 403 Forbidden│
     │      │ User can     │
     │      │ request new  │
     │      │ code         │
     │      └──────────────┘
     │
     ▼
9. VERIFICATION SUCCESS
   ┌──────────────────────┐
   │ email_validated      │
   │ = true               │
   │                      │
   │ User can now access  │
   │ all endpoints        │
   │ (no grace period     │
   │  restrictions)       │
   └──────────────────────┘
```

---

## Key Concepts

### Email Validation Status

Each user has an `email_validated` boolean field in the database that tracks whether their email has been verified. This field:
- Defaults to `false` when a user is created
- Is set to `true` after successful code verification
- Is checked during authentication (if email verification is enabled)

### Verification Code

Verification codes are:
- **Format**: Numeric codes (e.g., "123456")
- **Length**: 6 digits by default (configurable)
- **Storage**: Stored in the `user_secrets` table with:
  - `secret`: The verification code
  - `user_id`: Link to the user
  - `death_time`: Expiration timestamp
  - `reason`: Set to indicate this is an email verification code
  - `use_count`: Tracks how many times the code has been used
  - `use_count_max`: Maximum allowed uses (typically 1)

### Grace Period

The grace period is a configurable time window (measured from account creation) during which:
- Users can access the API without email verification
- Email validation checks are bypassed during authentication
- RBAC authorization still applies normally
- After expiration, email verification becomes mandatory

**Default**: 0 minutes (immediate verification required)

---

## Authentication Requirements

### Both Endpoints Require Authentication

**Critical Point**: Users must be logged in (have a valid JWT token) to:
1. Request a verification code (`POST /auth/email/send`)
2. Verify a code (`POST /auth/email/verify`)

### Why Authentication is Required

This design ensures:
- **Security**: Only the account owner can request verification codes
- **User Identification**: The system knows which user's email to verify
- **Prevention of Abuse**: Prevents unauthorized code requests for other users' emails
- **Audit Trail**: All verification attempts are tied to authenticated users

### Authentication Flow

When a user makes a request to email verification endpoints:

1. **Token Validation**: The JWT token is validated (decoded, checked for expiration, verifier token match)
2. **User Identification**: The `user_id` from the token identifies the user
3. **Email Validation Check**: If grace period has expired, the system checks if `email_validated` is true
4. **Request Processing**: If authentication succeeds, the verification code request/verification proceeds

---

## Verification Method

### Code-Based System (Not SSO Links)

CommandTower uses a **numeric code verification system**, not single-sign-on (SSO) links. This approach:

- **Works in any email client**: No need for special link handling
- **Mobile-friendly**: Easy to copy/paste or manually enter
- **Secure**: Codes expire quickly and are single-use
- **Simple UX**: Users enter code in the app interface

### Code Generation Process

On the backend, when a verification code is requested:

1. **Code Generation**: A random numeric code is generated (length configured via `verify_code_length`)
2. **Expiration Calculation**: Expiration time is calculated as current time + `verify_code_link_valid_for` duration
3. **Storage**: Code is stored in `user_secrets` table with:
   - The generated code in the `secret` field
   - Expiration time in `death_time` field
   - User association via `user_id`
   - Reason field set to indicate email verification
4. **Email Composition**: Email is composed with the code and expiration information
5. **Email Delivery**: Email is sent via ActiveMailer using configured SMTP settings

### Code Validation Process

When a user submits a code for verification:

1. **Code Lookup**: System searches `user_secrets` table for:
   - Matching `secret` (code value)
   - Associated `user_id` matches the authenticated user
   - `reason` indicates email verification
2. **Expiration Check**: Verifies `death_time` has not passed
3. **Usage Check**: Verifies `use_count` is less than `use_count_max`
4. **Validation Success**: If all checks pass:
   - `use_count` is incremented
   - User's `email_validated` field is set to `true`
   - Success response is returned
5. **Validation Failure**: If any check fails, returns 403 Forbidden with error details

---

## Grace Period Behavior

### How Grace Period Works

The grace period is calculated from the user's account creation time (`created_at`). During this period:

1. **Email Validation Bypass**: The email validation check in the authentication flow is skipped
2. **Full RBAC Access**: Users have complete API access based on their assigned roles
3. **Normal Authorization**: All RBAC authorization checks proceed normally
4. **No Restrictions**: Users can access any endpoint their roles permit

### Grace Period Expiration

After the grace period expires:

1. **Email Check Enforced**: The email validation check runs during authentication
2. **Blocking Behavior**: If `email_validated` is `false`, authentication fails with 412 Precondition Failed
3. **Error Message**: Returns "Email must be verified to continue"
4. **Authorization Blocked**: Authorization checks never run because authentication fails first

### Example Timeline

**Configuration**: `verify_email_required_within = 24.hours`

- **Day 1, 9:00 AM**: User registers → `created_at = 9:00 AM`, `email_validated = false`
- **Day 1, 9:05 AM**: User logs in → receives JWT token
- **Day 1, 9:10 AM**: User accesses admin endpoint → ✅ Success (within grace period, RBAC allows)
- **Day 1, 2:00 PM**: User accesses user endpoint → ✅ Success (within grace period, RBAC allows)
- **Day 2, 9:01 AM**: User accesses any endpoint → ❌ 412 Error (grace period expired, email not verified)
- **Day 2, 9:05 AM**: User verifies email → `email_validated = true`
- **Day 2, 9:10 AM**: User accesses admin endpoint → ✅ Success (email verified, RBAC allows)

### RBAC Access During Grace Period

**Important**: During the grace period, users have **full API access** based on their RBAC roles. This means:

- Users with `admin` role can access admin endpoints
- Users with `user` role can access user endpoints
- All role-based permissions apply normally
- The only difference is that email validation is not checked

This design allows users to:
- Complete onboarding flows
- Access necessary features immediately after registration
- Verify their email at their convenience (within the grace period)
- Experience no interruption in service during the grace period

---

## Backend Implementation

### Database Schema

#### Users Table
- `email`: String - User's email address
- `email_validated`: Boolean - Verification status (default: false)
- `created_at`: Timestamp - Used to calculate grace period expiration

#### UserSecrets Table
- `secret`: String - The verification code
- `user_id`: Foreign Key - Links to the user
- `death_time`: Timestamp - Code expiration time
- `reason`: String - Identifies this as an email verification code
- `use_count`: Integer - Number of times code has been used
- `use_count_max`: Integer - Maximum allowed uses (typically 1)

### Authentication Flow Integration

Email validation is integrated into the JWT authentication flow as follows:

1. **Token Decoding**: JWT token is decoded to extract `user_id`, `verifier_token`, and `generated_at`
2. **User Lookup**: User is retrieved from database using `user_id`
3. **Verifier Token Validation**: Token's `verifier_token` is compared with user's current `verifier_token`
4. **Email Validation Check** (if email verification enabled):
   - Calculate grace period expiration: `user.created_at + verify_email_required_within`
   - If current time is within grace period: Skip email validation check
   - If current time is after grace period: Check if `user.email_validated == true`
   - If email not validated and grace period expired: Return 412 Precondition Failed
5. **Authorization**: If authentication succeeds, RBAC authorization checks proceed

### Code Generation Service

The backend service that generates verification codes:

1. **Validates User**: Ensures user exists and is authenticated
2. **Checks Current Status**: If email already verified, returns success message
3. **Generates Code**: Creates random numeric code of configured length
4. **Calculates Expiration**: Sets expiration based on `verify_code_link_valid_for` configuration
5. **Creates UserSecret Record**: Stores code in database with expiration
6. **Sends Email**: Composes and sends email via ActiveMailer with:
   - The verification code
   - Expiration time information
   - User-friendly instructions
7. **Returns Response**: Confirms code has been sent

### Code Verification Service

The backend service that validates submitted codes:

1. **Validates User**: Ensures user exists and is authenticated
2. **Checks Current Status**: If email already verified, returns success message
3. **Looks Up Code**: Searches `user_secrets` for:
   - Matching code value
   - Associated with the authenticated user
   - Not expired (death_time > current time)
   - Not already used (use_count < use_count_max)
4. **Validates Code**: If code found and valid:
   - Increments `use_count`
   - Updates user's `email_validated` to `true`
   - Returns success response
5. **Handles Invalid Code**: If code not found, expired, or already used:
   - Returns 403 Forbidden
   - Provides appropriate error message

### Email Delivery

Email delivery is handled by Rails' ActiveMailer:

1. **SMTP Configuration**: Uses configured SMTP settings (Gmail, custom SMTP, etc.)
2. **Email Template**: Uses email template with:
   - Verification code prominently displayed
   - Expiration time
   - Instructions for entering code
   - Support contact information (if configured)
3. **Delivery**: Sends email to user's registered email address
4. **Error Handling**: Logs delivery errors and handles failures gracefully

---

## Configuration Options

### Email Verification Configuration

Email verification is configured in the CommandTower initializer:

#### Enable/Disable Email Verification
- **Setting**: `email_verify_config.enable`
- **Type**: Boolean
- **Default**: `false`
- **Description**: Master switch for email verification feature

#### Grace Period Duration
- **Setting**: `email_verify_config.verify_email_required_within`
- **Type**: ActiveSupport::Duration
- **Default**: `0.minutes` (immediate verification required)
- **Description**: Time window after account creation during which email verification is not required
- **Examples**:
  - `0.minutes` - Immediate verification required
  - `24.hours` - 24-hour grace period
  - `7.days` - 7-day grace period

#### Code Validity Duration
- **Setting**: `email_verify_config.verify_code_link_valid_for`
- **Type**: ActiveSupport::Duration
- **Default**: `10.minutes`
- **Description**: How long verification codes remain valid after generation
- **Examples**:
  - `10.minutes` - Codes expire after 10 minutes
  - `30.minutes` - Codes expire after 30 minutes
  - `1.hour` - Codes expire after 1 hour

#### Code Length
- **Setting**: `email_verify_config.verify_code_length`
- **Type**: Integer
- **Default**: `6`
- **Description**: Number of digits in verification codes
- **Examples**:
  - `4` - 4-digit codes (e.g., "1234")
  - `6` - 6-digit codes (e.g., "123456")
  - `8` - 8-digit codes (e.g., "12345678")

### Email Configuration

Email delivery is configured separately:

- **SMTP Address**: `config.email.address` (default: "smtp.gmail.com")
- **SMTP Port**: `config.email.port` (default: 587)
- **Username**: `config.email.user_name` (default: `ENV['GMAIL_USER_NAME']`)
- **Password**: `config.email.password` (default: `ENV['GMAIL_PASSWORD']`)
- **Authentication**: `config.email.authentication` (default: "plain")
- **TLS**: `config.email.enable_starttls_auto` (default: true)

---

## API Endpoints

### 1. Send Verification Code

**Endpoint**: `POST /auth/email/send`

**Authentication**: Required (Bearer token)

**Request Headers**:
```
Authorization: Bearer {jwt_token}
Content-Type: application/json
```

**Request Body**: None

**Response** (201 Created):
```json
{
  "message": "Successfully sent Email verification code"
}
```

**Response** (200 OK - if already verified):
```json
{
  "message": "Email is already verified. No code required"
}
```

**Error Responses**:
- `401 Unauthorized`: Missing or invalid token
- `412 Precondition Failed`: Grace period expired with unverified email

**Backend Behavior**:
1. Validates JWT token and identifies user
2. Checks if email is already verified (returns 200 if yes)
3. Generates new verification code
4. Stores code in `user_secrets` with expiration
5. Sends email with code
6. Returns success response

### 2. Verify Code

**Endpoint**: `POST /auth/email/verify`

**Authentication**: Required (Bearer token)

**Request Headers**:
```
Authorization: Bearer {jwt_token}
Content-Type: application/json
```

**Request Body**:
```json
{
  "code": "123456"
}
```

**Response** (201 Created):
```json
{
  "message": "Successfully verified email"
}
```

**Response** (200 OK - if already verified):
```json
{
  "message": "Email is already verified."
}
```

**Error Responses**:
- `401 Unauthorized`: Missing or invalid token
- `412 Precondition Failed`: Grace period expired with unverified email
- `403 Forbidden`: Invalid, expired, or already-used verification code
- `400 Bad Request`: Missing or invalid request body

**Backend Behavior**:
1. Validates JWT token and identifies user
2. Checks if email is already verified (returns 200 if yes)
3. Looks up code in `user_secrets` for the authenticated user
4. Validates code is not expired and not already used
5. If valid: increments use_count, sets `email_validated = true`
6. Returns success response

---

## Error Handling

### Authentication Errors (401)

**Scenario**: User tries to request/verify code but authentication fails

**Possible Causes**:
- Missing Authorization header
- Invalid or expired JWT token

**Response**:
```json
{
  "status": "401",
  "message": "Unauthorized Access. Invalid Authorization token"
}
```

### Email Validation Errors (412)

**Scenario**: User's email is not validated and grace period has expired

**Possible Causes**:
- Grace period expired and email not verified

**Response**:
```json
{
  "status": "412",
  "message": "Email must be verified to continue",
  "meta": {
    "email_validated": false
  }
}
```

### Invalid Code Errors (403)

**Scenario**: User submits invalid, expired, or already-used code

**Possible Causes**:
- Code doesn't exist
- Code has expired (past `death_time`)
- Code has already been used (use_count >= use_count_max)
- Code belongs to different user

**Response**:
```json
{
  "status": "403",
  "message": "Invalid verification code"
}
```

### Already Verified (200)

**Scenario**: User requests code or verifies code but email is already verified

**Response**:
```json
{
  "message": "Email is already verified. No code required"
}
```
or
```json
{
  "message": "Email is already verified."
}
```

### Resend Capability

Users can request a new verification code if:
- Previous code expired
- Previous code was lost
- User needs a fresh code

Simply call `POST /auth/email/send` again. The system will:
- Invalidate or ignore the previous code (if not used)
- Generate a new code
- Send a new email

---

## Security Considerations

### Code Security

1. **Single-Use Codes**: Codes are designed to be used once (use_count_max = 1)
2. **Short Expiration**: Codes expire quickly (default 10 minutes) to limit exposure window
3. **User Association**: Codes are tied to specific users and cannot be used by others
4. **Secure Storage**: Codes are stored in database, not in URLs or client-side storage

### Authentication Requirements

1. **Token Required**: Both endpoints require valid JWT tokens
2. **User Verification**: System verifies the authenticated user matches the code's user
3. **Prevents Cross-User Attacks**: Users cannot verify codes for other users' emails

### Rate Limiting Considerations

While not explicitly implemented in the base system, consider:
- Limiting code request frequency per user
- Implementing cooldown periods between code requests
- Monitoring for abuse patterns

### Email Security

1. **SMTP Security**: Use TLS/SSL for email transmission
2. **Email Content**: Avoid including sensitive information beyond the code
3. **Expiration Communication**: Clearly communicate code expiration to users

### Grace Period Security

1. **Time-Based**: Grace period is calculated from account creation, not login time
2. **Consistent Enforcement**: Grace period expiration is checked on every authenticated request
3. **No Bypass**: Once grace period expires, verification is mandatory

---

## Complete User Journey

### Scenario 1: Immediate Verification Required (Grace Period = 0)

1. **Registration** (9:00 AM)
   - User creates account via `POST /auth/create`
   - Account created with `email_validated = false`
   - `created_at = 9:00 AM`

2. **Login** (9:01 AM)
   - User logs in via `POST /auth/login`
   - Receives JWT token
   - Token includes user information

3. **API Access Attempt** (9:02 AM)
   - User tries to access `GET /user/`
   - Authentication checks email validation
   - Grace period = 0, so check runs immediately
   - `email_validated = false` → 412 Precondition Failed
   - User must verify email before accessing API

4. **Request Verification Code** (9:03 AM)
   - User calls `POST /auth/email/send`
   - System generates 6-digit code
   - Code stored with 10-minute expiration
   - Email sent with code

5. **Receive Email** (9:04 AM)
   - User receives email with code "123456"
   - Email shows code expires at 9:14 AM

6. **Verify Code** (9:05 AM)
   - User calls `POST /auth/email/verify` with `{ "code": "123456" }`
   - System validates code
   - Sets `email_validated = true`
   - Returns success

7. **API Access** (9:06 AM)
   - User accesses `GET /user/`
   - Authentication succeeds (email validated)
   - Authorization checks RBAC roles
   - Request succeeds

### Scenario 2: 24-Hour Grace Period

1. **Registration** (Day 1, 9:00 AM)
   - User creates account
   - `created_at = Day 1, 9:00 AM`
   - `email_validated = false`

2. **Login** (Day 1, 9:05 AM)
   - User logs in
   - Receives JWT token

3. **Immediate API Access** (Day 1, 9:10 AM)
   - User accesses `GET /admin/` (has admin role)
   - Authentication: Grace period active (24 hours from 9:00 AM)
   - Email validation check bypassed
   - Authorization: RBAC allows admin access
   - ✅ Request succeeds

4. **Continue Using API** (Day 1, throughout the day)
   - User accesses various endpoints
   - All requests succeed (within grace period)
   - Email validation not checked

5. **Request Verification Code** (Day 1, 2:00 PM)
   - User calls `POST /auth/email/send`
   - Receives code via email
   - Can verify immediately or later

6. **Verify Code** (Day 1, 2:05 PM)
   - User verifies code
   - `email_validated = true`
   - No change in API access (still within grace period)

7. **After Grace Period** (Day 2, 9:01 AM)
   - Grace period expired (24 hours from Day 1, 9:00 AM)
   - User accesses any endpoint
   - Authentication: Email validation check runs
   - `email_validated = true` → ✅ Check passes
   - Authorization: RBAC checks proceed
   - ✅ Request succeeds

### Scenario 3: Grace Period Expires Without Verification

1. **Registration** (Day 1, 9:00 AM)
   - User creates account
   - `created_at = Day 1, 9:00 AM`

2. **Login & Usage** (Day 1, 9:05 AM - Day 2, 8:59 AM)
   - User logs in and uses API successfully
   - All requests succeed (within grace period)
   - User never verifies email

3. **Grace Period Expires** (Day 2, 9:01 AM)
   - 24 hours have passed since account creation
   - Grace period expired

4. **API Access Blocked** (Day 2, 9:02 AM)
   - User tries to access `GET /user/`
   - Authentication: Email validation check runs
   - `email_validated = false` → ❌ 412 Precondition Failed
   - Error: "Email must be verified to continue"
   - Authorization never runs (authentication failed)

5. **User Verifies Email** (Day 2, 9:05 AM)
   - User requests verification code
   - Receives code via email
   - Verifies code
   - `email_validated = true`

6. **API Access Restored** (Day 2, 9:06 AM)
   - User accesses `GET /user/`
   - Authentication: Email validation check passes
   - Authorization: RBAC checks proceed
   - ✅ Request succeeds

---

## Summary

Email verification in CommandTower provides a flexible, secure system for ensuring users have access to their registered email addresses. Key takeaways:

1. **Code-Based System**: Uses numeric codes, not SSO links
2. **Authentication Required**: Users must be logged in to request/verify codes
3. **Grace Period**: Configurable time window before verification becomes mandatory
4. **Full RBAC Access**: During grace period, users have complete API access based on roles
5. **Secure Implementation**: Codes expire quickly, are single-use, and tied to specific users
6. **Flexible Configuration**: Grace period duration, code length, and expiration are all configurable

This system balances security requirements with user experience, allowing immediate API access during onboarding while ensuring email verification is completed within a reasonable timeframe.
