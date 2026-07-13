# Password Reset (Forgot Password) Endpoint

## Table of Contents

1. [Overview](#overview)
2. [High-Level Details](#high-level-details)
3. [Request Schema](#request-schema)
4. [Response Schema](#response-schema)
5. [Error Scenarios & Status Codes](#error-scenarios--status-codes)
6. [Status Code Summary](#status-code-summary)
7. [Security Considerations](#security-considerations)
8. [Implementation Notes](#implementation-notes)
9. [Example Requests/Responses](#example-requestsresponses)
10. [Related Endpoints](#related-endpoints)

---

## Overview

The forgot password endpoint allows users to request a password reset by email. This endpoint generates a secure reset token and sends it to the user's email address. The endpoint follows security best practices by not revealing whether an email exists in the system, preventing user enumeration attacks.

### Key Characteristics

- **Public Endpoint**: No authentication required
- **Email-Based**: Uses email address to identify the user
- **Token Generation**: Creates secure, time-limited reset tokens
- **Email Delivery**: Sends reset link/token via email
- **Security-First**: Always returns success (even if email doesn't exist) to prevent enumeration
- **Rate Limiting**: Should be protected against abuse

---

## High-Level Details

### Purpose

The forgot password endpoint enables users who have forgotten their password to request a password reset. The system:

1. Accepts an email address from the user
2. Validates the email format
3. If valid, generates a secure reset token
4. Stores the token with an expiration timestamp
5. Sends an email containing the reset link/token
6. Returns a success response (regardless of whether the email exists)

### Endpoint Details

- **Route**: `POST /auth/password/forgot/send` - Request password reset email
- **Route**: `POST /auth/password/forgot/validate` - Validate reset token
- **Route**: `POST /auth/password/forgot/reset` - Reset password with token
- **Authentication**: Not required (public endpoints)
- **Controller**: `CommandTower::Auth::PlainTextController`
  - `password_forgot_send_post`
  - `password_forgot_validate_post`
  - `password_forgot_reset_post`
- **Services**: `CommandTower::LoginStrategy::PlainText::PasswordReset`
  - `Send`
  - `Validate`
  - `Reset`

### Related: authenticated password change

Recovery does **not** require a JWT and does **not** rotate `verifier_token` after a successful reset (known gap vs authenticated change). For signed-in users changing their password, use **`POST /auth/password/change`** (`ChangePassword`) instead — that path proves the current password, updates the digest, and rotates the verifier atomically so all sessions end. See [change_password_workflow.md](change_password_workflow.md).

### Request Flow

1. **Client Request**: User submits email address
2. **Email Validation**: System validates email format
3. **User Lookup**: System checks if user exists (silently, no error if not found)
4. **Token Generation**: If user exists, generates secure reset token
5. **Token Storage**: Stores token with expiration timestamp in database
6. **Email Delivery**: Sends email with reset link/token
7. **Response**: Returns success message (same response whether user exists or not)

### Response Behavior

- **Always Returns Success**: Returns 200/201 on valid request format (security best practice)
- **No User Enumeration**: Does not reveal whether email exists in system
- **Email Delivery Failures**: Only returns 500 if email delivery fails (and user exists)
- **Generic Message**: Uses generic success message that doesn't reveal user existence

### Security Considerations

- **Rate Limiting**: Should be implemented to prevent abuse
- **Token Expiration**: Tokens should expire (typically 1-24 hours)
- **Single-Use Tokens**: Tokens should be invalidated after use
- **No User Enumeration**: Same response for existing/non-existing emails
- **Secure Token Generation**: Uses cryptographically secure random token generation

### Related Endpoints

- **Password Reset Send**: `POST /auth/password/forgot/send` - Request password reset email
- **Password Reset Validate**: `POST /auth/password/forgot/validate` - Validate reset token
- **Password Reset**: `POST /auth/password/forgot/reset` - Reset password with token

---

## Email Requirement for Enhanced Security

Command Tower supports an optional email requirement feature that adds an additional security layer to the password reset flow. When enabled, users must provide both the reset token and their email address when validating or resetting their password.

### Security Benefits

- **Prevents Brute Force Attacks**: Attackers must know both the token and the correct email address, making brute force attacks significantly more difficult
- **Additional Verification Layer**: Even if a token is compromised, the attacker must also know the user's email address
- **Backward Compatible**: The feature defaults to `false`, ensuring existing implementations continue to work without changes

### How It Works

1. **Configuration**: Enable the feature by setting `require_email: true` in the password reset configuration
2. **Email Template**: When enabled, the reset email link automatically includes the email as a query parameter
3. **Validation**: Both validate and reset endpoints check:
   - If `require_email` is enabled and email is missing → returns 400 "Email is required"
   - If email is provided → verifies it matches the user's email associated with the token
   - If email doesn't match → returns 401 "Invalid token" (same message as invalid token for security)

### Email Normalization

Email addresses are normalized before comparison:
- Converted to lowercase
- Whitespace trimmed
- This ensures "User@Example.com" matches "user@example.com"

### Error Responses

When `require_email: true`:
- Missing email: `400 Bad Request` with message "Email is required"
- Email mismatch: `401 Unauthorized` with message "Invalid token" (generic message for security)

---

## Request Schema

**Endpoint**: `POST /auth/password/forgot/send`

**Headers**:
```
Content-Type: application/json
```

**Request Body**:
```json
{
  "email": "user@example.com"
}
```

**Schema Definition** (following command_tower patterns):
```ruby
# lib/command_tower/schema/auth/plain_text/password_forgot/send/request.rb
module CommandTower
  module Schema
    module Auth
      module PlainText
        module PasswordForgot
          module Send
            class Request < JsonSchematize::Generator
              schema_default option: :dig_type, value: :string

              add_field name: :email, type: String, required: true
            end
          end
        end
      end
    end
  end
end
```

**Field Validation**:
- `email`: Required, must be valid email format, case-insensitive

**Field Types**:
- `email`: String (required) - User's email address

---

## Response Schema

**Success Response** (200 OK or 201 Created):

```json
{
  "message": "If an account exists with that email, a password reset link has been sent."
}
```

**Schema Definition**:
```ruby
# lib/command_tower/schema/auth/plain_text/password_forgot/send/response.rb
module CommandTower
  module Schema
    module Auth
      module PlainText
        module PasswordForgot
          module Send
            class Response < JsonSchematize::Generator
              add_field name: :message, type: String
            end
          end
        end
      end
    end
  end
end
```

**Response Schema Fields**:
- `message`: String (required) - Success message (generic, doesn't reveal if email exists)

**Response Headers**:
- No special headers required (this is a public endpoint)

---

## Error Scenarios & Status Codes

### 1. 400 Bad Request - Invalid Arguments

**Scenario**: Missing or invalid email format

**Response**:
```json
{
  "message": "Invalid request parameters",
  "status": "400",
  "invalid_arguments": [
    {
      "schema": {...},
      "argument": "email",
      "argument_type": "String",
      "reason": "Email is required and must be a valid email address"
    }
  ],
  "invalid_argument_keys": ["email"]
}
```

**Schema**: `CommandTower::Schema::Error::InvalidArgumentResponse`

**Triggers**:
- Email field missing from request body
- Email format invalid (doesn't match email regex pattern)
- Email is empty string
- Email is null

**Example Request** (Invalid):
```json
{
  "email": "not-an-email"
}
```

**Example Request** (Missing Field):
```json
{}
```

---

### 2. 400 Bad Request - Generic Error

**Scenario**: Request body parsing error or other client-side issues

**Response**:
```json
{
  "status": "400",
  "message": "Invalid request format"
}
```

**Schema**: `CommandTower::Schema::Error::Base`

**Triggers**:
- Malformed JSON in request body
- Invalid Content-Type header
- Request body parsing failure
- Other client-side validation errors

---

### 3. 429 Too Many Requests - Rate Limiting

**Scenario**: Too many password reset requests from same IP/email

**Response**:
```json
{
  "status": "429",
  "message": "Too many password reset requests. Please try again later"
}
```

**Schema**: `CommandTower::Schema::Error::Base`

**Triggers**:
- Rate limiting middleware detects too many requests
- Too many requests from same email address within time window
- Too many requests from same IP address within time window
- Global rate limit exceeded

**Rate Limiting Considerations**:
- Should be implemented at application level (per email address)
- Should be implemented at IP level (per IP address)
- Should be implemented at global level (total requests per time window)
- Typical limits: 3-5 requests per email per hour, 10-20 requests per IP per hour

---

## Status Code Summary

### Send Endpoint (`POST /auth/password/forgot/send`)

| Status Code | Scenario | Response Schema | Notes |
|------------|----------|----------------|-------|
| **200 OK** | Success (email sent or user doesn't exist) | `PasswordForgot::Send::Response` | Always returns 200, never 500 |
| **400 Bad Request** | Invalid email format, missing email, malformed request | `InvalidArgumentResponse` or `Error::Base` | Client-side validation errors |

### Validate Endpoint (`POST /auth/password/forgot/validate`)

| Status Code | Scenario | Response Schema | Notes |
|------------|----------|----------------|-------|
| **200 OK** | Token is valid | `PasswordForgot::Validate::Response` | Returns valid=true and expires_at |
| **400 Bad Request** | Missing token, missing email (when require_email: true) | `InvalidArgumentResponse` or `Error::Base` | Client-side validation error |
| **401 Unauthorized** | Invalid, expired, used token, or email mismatch | `Error::Base` | Generic "Invalid token" message |

### Reset Endpoint (`POST /auth/password/forgot/reset`)

| Status Code | Scenario | Response Schema | Notes |
|------------|----------|----------------|-------|
| **200 OK** | Password reset successful | `PasswordForgot::Reset::Response` | Password updated |
| **400 Bad Request** | Missing token, missing email (when require_email: true), password validation errors, password mismatch | `InvalidArgumentResponse` or `Error::Base` | Client-side validation errors |
| **401 Unauthorized** | Invalid, expired, used token, or email mismatch | `Error::Base` | Generic "Invalid token" message |

---

## Security Considerations

### 1. User Enumeration Prevention

**Critical Security Practice**: Always return the same success response (200/201) regardless of whether the email exists in the system. This prevents attackers from determining which email addresses are registered.

**Implementation**:
- If user exists: Generate token, store it, send email, return success
- If user doesn't exist: Return success without generating token or sending email
- Use generic message: "If an account exists with that email, a password reset link has been sent."

### 2. Rate Limiting

**Purpose**: Prevent abuse and email spam

**Implementation Levels**:
1. **Per Email Address**: Limit requests per email (e.g., 3-5 per hour)
2. **Per IP Address**: Limit requests per IP (e.g., 10-20 per hour)
3. **Global**: Limit total requests across all sources

**Configuration**:
- Should be configurable via CommandTower configuration
- Should use Redis or similar for distributed rate limiting
- Should return 429 status when limit exceeded

### 3. Token Generation

**Requirements**:
- Use cryptographically secure random token generation
- Token should be sufficiently long (e.g., 32+ characters)
- Token should be URL-safe
- Token should be unique (check for collisions)

**Example Implementation**:
```ruby
SecureRandom.alphanumeric(32) # or similar secure method
```

### 4. Token Storage

**Database Schema** (in `user_secrets` table or similar):
- `secret`: String - The reset token
- `user_id`: Foreign Key - Links to the user
- `death_time`: Timestamp - Token expiration time
- `reason`: String - Identifies this as a password reset token
- `use_count`: Integer - Number of times token has been used
- `use_count_max`: Integer - Maximum allowed uses (typically 1)

**Token Expiration**:
- Default: 1 hour (configurable)
- Should be configurable via CommandTower configuration
- Expired tokens should be automatically cleaned up

### 5. Email Security

**Email Content**:
- Should include reset link with token
- Should clearly show expiration time
- Should include security warning if user didn't request reset
- Should not include sensitive information beyond the token

**Email Template**:
- Should be configurable via CommandTower configuration
- Should use secure email delivery (TLS/SSL)
- Should include app branding and clear instructions

### 6. Token Invalidation

**Single-Use Tokens**:
- Tokens should be invalidated after successful password reset
- Tokens should be invalidated if expired
- Tokens should be invalidated if user requests a new reset

**Implementation**:
- Set `use_count_max` to 1
- Increment `use_count` when token is used
- Check `use_count < use_count_max` during validation

### 7. Email Requirement Feature

**Optional Email Verification**:
- When `require_email` config is enabled, users must provide both token and email
- Email is normalized (lowercase, trimmed) before comparison
- Email must match the user's email associated with the token
- Provides additional security layer against brute force attacks

**Implementation**:
- Email validation is handled by `EmailValidationHelper` module
- Shared logic used by both Validate and Reset services
- Email parameter is optional in request schemas
- When required but missing, returns 400 "Email is required"
- When provided but mismatched, returns 401 "Invalid token" (generic for security)

---

## Implementation Notes

### 1. Service Implementation Pattern

The service should follow the command_tower service pattern:

```ruby
# app/services/command_tower/login_strategy/plain_text/password_reset/request.rb
module CommandTower::LoginStrategy::PlainText::PasswordReset
  class Request < CommandTower::ServiceBase
    on_argument_validation :fail_early

    validate :email, is_a: String, required: true

    def call
      # Find user by email (silently, don't fail if not found)
      user = User.find_by(email: email.downcase.strip)

      # If user exists, generate token and send email
      if user
        result = GenerateToken.(user: user)
        if result.success?
          SendEmail.(user: user, token: result.token)
        else
          # Only fail if email delivery fails
          context.fail!(msg: "Unable to send password reset email. Please try again later", status: 500)
          return
        end
      end

      # Always return success (security: don't reveal if user exists)
      context.message = "If an account exists with that email, a password reset link has been sent."
    end
  end
end
```

### 2. Controller Implementation Pattern

The controller should follow the command_tower controller pattern:

```ruby
# In CommandTower::Auth::PlainTextController
def forgot_password_post
  result = CommandTower::LoginStrategy::PlainText::PasswordReset::Request.(**forgot_password_params)
  if result.success?
    schema = CommandTower::Schema::Auth::PlainText::PasswordForgot::Response.new(
      message: result.message
    )
    status = 200
    schema_succesful!(status:, schema:)
  else
    if result.invalid_arguments
      invalid_arguments!(
        status: 400,
        message: result.msg,
        argument_object: result.invalid_argument_hash,
        schema: CommandTower::Schema::Auth::PlainText::PasswordForgot::Request
      )
    else
      schema = CommandTower::Schema::Error::Base.new(status: result.status || 500, message: result.msg)
      status = result.status || 500
      render(json: schema.to_h, status:)
    end
  end
end

private

def forgot_password_params
  {
    email: params[:email]
  }
end
```

### 3. Route Configuration

Add route to `config/routes.rb`:

```ruby
scope "auth" do
  constraints(->(_req) { CommandTower.config.login.plain_text.enable? }) do
    post "/password/forgot", to: "command_tower/auth/plain_text#forgot_password_post", as: :"#{append_to_ass}_auth_password_forgot_post"
  end
end
```

### 4. Email Template

The email template should include:
- Reset link with token: Uses `reset_password_path` config appended to `composed_url`
  - Format when `require_email: false`: `{composed_url}{reset_password_path}?token={token}`
  - Format when `require_email: true`: `{composed_url}{reset_password_path}?token={token}&email={email}`
- Alternative reset URL link: Shows the base reset password URL for manual entry
- Expiration time: "This link will expire in {token_valid_for}"
- Security warning: "If you didn't request this, please ignore this email"
- App branding and clear instructions

The email template automatically:
- Includes email parameter in URL when `require_email` is enabled
- Uses `reset_password_path` config value instead of hardcoded path
- URL-encodes email parameter for safe transmission

### 5. Token Generation Service

```ruby
# app/services/command_tower/login_strategy/plain_text/password_reset/generate_token.rb
module CommandTower::LoginStrategy::PlainText::PasswordReset
  class GenerateToken < CommandTower::ServiceBase
    validate :user, is_a: User, required: true

    def call
      # Generate secure token
      token = SecureRandom.alphanumeric(32)

      # Calculate expiration (configurable, default 1 hour)
      expires_at = CommandTower.config.password_reset.token_valid_for.from_now

      # Store token in user_secrets
      user_secret = UserSecret.create!(
        user: user,
        secret: token,
        death_time: expires_at,
        reason: "password_reset",
        use_count: 0,
        use_count_max: 1
      )

      context.token = token
      context.expires_at = expires_at
    end
  end
end
```

### 6. Email Sending Service

The `Send` service automatically:
- Passes email, `require_email` flag, and `reset_password_path` to the mailer
- Mailer makes these available to the email template as instance variables
- Template conditionally includes email in URL based on `require_email` setting

### 7. Email Validation Helper

A shared helper module (`EmailValidationHelper`) provides email validation logic used by both Validate and Reset services:

```ruby
# app/services/command_tower/login_strategy/plain_text/password_reset/email_validation_helper.rb
module CommandTower::LoginStrategy::PlainText::PasswordReset
  module EmailValidationHelper
    def self.validate_email_with_token(email:, token:, context:, access_count: false)
      # Checks if require_email is enabled and email is missing
      # If email provided, verifies token and compares emails (normalized)
      # Returns hash with :user and :verify_result
    end
  end
end
```

**Usage in Services**:
- Both `Validate` and `Reset` services call this helper
- Helper handles email requirement checking and email matching
- Returns verification result to avoid duplicate token verification

---

## Example Requests/Responses

### Example 1: Successful Request (User Exists)

**Request**:
```bash
curl -X POST https://api.example.com/auth/password/forgot/send \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com"}'
```

**Response** (200 OK):
```json
{
  "message": "If an account exists with that email, a password reset link has been sent."
}
```

**What Happens**:
1. System validates email format ✓
2. System finds user with email "user@example.com" ✓
3. System generates secure reset token
4. System stores token with 1-hour expiration
5. System sends email with reset link
6. System returns success response

---

### Example 2: Successful Request (User Doesn't Exist)

**Request**:
```bash
curl -X POST https://api.example.com/auth/password/forgot/send \
  -H "Content-Type: application/json" \
  -d '{"email": "nonexistent@example.com"}'
```

**Response** (200 OK):
```json
{
  "message": "If an account exists with that email, a password reset link has been sent."
}
```

**What Happens**:
1. System validates email format ✓
2. System checks for user with email "nonexistent@example.com" ✗ (not found)
3. System returns success response (same as if user exists)
4. No token generated, no email sent (but client doesn't know this)

**Security Note**: This prevents user enumeration attacks.

---

### Example 3: Invalid Email Format

**Request**:
```bash
curl -X POST https://api.example.com/auth/password/forgot/send \
  -H "Content-Type: application/json" \
  -d '{"email": "not-an-email"}'
```

**Response** (400 Bad Request):
```json
{
  "message": "Invalid request parameters",
  "status": "400",
  "invalid_arguments": [
    {
      "schema": {...},
      "argument": "email",
      "argument_type": "String",
      "reason": "Email is required and must be a valid email address"
    }
  ],
  "invalid_argument_keys": ["email"]
}
```

---

### Example 4: Missing Email Field

**Request**:
```bash
curl -X POST https://api.example.com/auth/password/forgot/send \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Response** (400 Bad Request):
```json
{
  "message": "Invalid request parameters",
  "status": "400",
  "invalid_arguments": [
    {
      "schema": {...},
      "argument": "email",
      "argument_type": "String",
      "reason": "Email is required"
    }
  ],
  "invalid_argument_keys": ["email"]
}
```

---

### Example 5: Validate Token

**Request** (without email - when require_email: false):
```bash
curl -X POST https://api.example.com/auth/password/forgot/validate \
  -H "Content-Type: application/json" \
  -d '{"token": "reset_token_from_email"}'
```

**Request** (with email - when require_email: true):
```bash
curl -X POST https://api.example.com/auth/password/forgot/validate \
  -H "Content-Type: application/json" \
  -d '{
    "token": "reset_token_from_email",
    "email": "user@example.com"
  }'
```

**Response** (200 OK):
```json
{
  "valid": true,
  "expires_at": "2025-01-16T10:00:00Z"
}
```

**Response** (400 Bad Request - Email Required):
```json
{
  "status": "400",
  "message": "Email is required"
}
```

**Response** (401 Unauthorized - Invalid Token or Email Mismatch):
```json
{
  "status": "401",
  "message": "Invalid token"
}
```

---

### Example 6: Reset Password

**Request** (without email - when require_email: false):
```bash
curl -X POST https://api.example.com/auth/password/forgot/reset \
  -H "Content-Type: application/json" \
  -d '{
    "token": "reset_token_from_email",
    "password": "new_password123",
    "password_confirmation": "new_password123"
  }'
```

**Request** (with email - when require_email: true):
```bash
curl -X POST https://api.example.com/auth/password/forgot/reset \
  -H "Content-Type: application/json" \
  -d '{
    "token": "reset_token_from_email",
    "email": "user@example.com",
    "password": "new_password123",
    "password_confirmation": "new_password123"
  }'
```

**Response** (200 OK):
```json
{
  "message": "Password has been successfully reset"
}
```

**Response** (400 Bad Request - Email Required):
```json
{
  "status": "400",
  "message": "Email is required"
}
```

**Response** (401 Unauthorized - Invalid Token or Email Mismatch):
```json
{
  "status": "401",
  "message": "Invalid token"
}
```

**Response** (400 Bad Request - Password Mismatch):
```json
{
  "message": "Invalid request parameters",
  "status": "400",
  "invalid_arguments": [
    {
      "argument": "password_confirmation",
      "msg": "doesn't match Password"
    }
  ],
  "invalid_argument_keys": ["password_confirmation"]
}
```

---

## Related Endpoints

### Password Reset Validate

**Endpoint**: `POST /auth/password/forgot/validate`

**Purpose**: Check if a reset token is valid before showing the reset form

**Request** (without email):
```json
{
  "token": "reset_token_from_email"
}
```

**Request** (with email - when require_email: true):
```json
{
  "token": "reset_token_from_email",
  "email": "user@example.com"
}
```

**Response** (200 OK):
```json
{
  "valid": true,
  "expires_at": "2025-01-16T10:00:00Z"
}
```

**Error Responses**:
- `400 Bad Request`: Missing token, missing email (when require_email: true)
- `401 Unauthorized`: Invalid, expired, used token, or email mismatch (generic message)

---

### Password Reset

**Endpoint**: `POST /auth/password/forgot/reset`

**Purpose**: Reset password using the token from the email

**Request** (without email):
```json
{
  "token": "reset_token_from_email",
  "password": "new_password",
  "password_confirmation": "new_password"
}
```

**Request** (with email - when require_email: true):
```json
{
  "token": "reset_token_from_email",
  "email": "user@example.com",
  "password": "new_password",
  "password_confirmation": "new_password"
}
```

**Response** (200 OK):
```json
{
  "message": "Password has been successfully reset"
}
```

**Error Responses**:
- `400 Bad Request`: Missing token, missing email (when require_email: true), password validation errors, password mismatch
- `401 Unauthorized`: Invalid, expired, used token, or email mismatch (generic message)

---

## Configuration

### Password Reset Configuration

Password reset should be configurable in the CommandTower initializer:

```ruby
CommandTower.configure do |config|
  config.login.plain_text.password_reset.enabled = true
  config.login.plain_text.password_reset.token_valid_for = 1.hour
  config.login.plain_text.password_reset.token_length = 32
  config.login.plain_text.password_reset.custom_template_name = "password_reset"
  config.login.plain_text.password_reset.require_email = false  # Enable for enhanced security
  config.login.plain_text.password_reset.reset_password_path = "/reset-password"  # Frontend reset path

  # Rate limiting
  config.password_reset.rate_limit.per_email = 3  # requests per hour
  config.password_reset.rate_limit.per_ip = 10     # requests per hour
end
```

### Configuration Options

- `enabled`: Boolean - Master switch for password reset feature (default: `true`)
- `token_valid_for`: ActiveSupport::Duration - Token expiration time (default: `10.minutes`, max: `24.hours`)
- `token_length`: Integer - Length of reset token (default: `32`, range: 16-64)
- `custom_template_name`: String or Nil - Email template name (default: `nil`, uses "reset_password")
- `require_email`: Boolean - Require email with token for validation/reset (default: `false`)
- `reset_password_path`: String - Path to frontend reset password page (default: `"/reset-password"`)
  - This path is appended to `config.app.composed_url` to form the full URL in email templates
- `rate_limit.per_email`: Integer - Max requests per email per hour
- `rate_limit.per_ip`: Integer - Max requests per IP per hour

---

## Summary

The forgot password endpoint provides a secure way for users to request password resets:

1. **Public Endpoint**: No authentication required
2. **Email-Based**: Uses email to identify users
3. **Secure**: Prevents user enumeration by always returning success
4. **Token-Based**: Generates secure, time-limited reset tokens
5. **Rate Limited**: Protected against abuse
6. **Error Handling**: Comprehensive error scenarios with appropriate status codes

**Key Security Features**:
- No user enumeration (same response for all valid emails)
- Secure token generation
- Token expiration
- Single-use tokens
- Rate limiting
- Secure email delivery

**Status Codes**:
- `200 OK` / `201 Created`: Success (email sent or user doesn't exist)
- `400 Bad Request`: Invalid email format or missing field
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Email delivery failure

This endpoint follows command_tower patterns and integrates seamlessly with the existing authentication system.
