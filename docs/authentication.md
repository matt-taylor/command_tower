# Authentication

Authentication is backed by JWT tokens. There are many options to the JWT configuration. Check out [Initializing](initializing.md) to understand where to find the config.

## Usage
Authenticating a User is straightforward via Rails actions. In each controller that you want to authenticate, add the following
```ruby
before_action :authenticate_user!
```

This action will authenticate the user and set `current_user` to the user passed in via the JWT token.

**Token Extraction**: The authentication system uses a centralized `CommandTower::Jwt::AuthorizationHelper` module that handles all token extraction logic. It checks the `Authorization` header first, then falls back to the HttpOnly cookie (if cookie authentication is enabled). All header and cookie access is abstracted through this helper module.

Every API request will return a header that indicates when the current token will expire:
```
X-Authentication-Expire="2025-01-16 04:36:29 +0000"
```

### Header Token
For routes that expect user authentication, the client must set the Header value:
```
Authorization: Bearer {token value}
```

**Important**: The header format must be exactly `Bearer {token}` with a space between "Bearer" and the token. Malformed headers will result in `401 Unauthorized` with the message "Invalid Bearer token format".

### Cookie Token (Optional)
CommandTower supports HttpOnly cookie-based authentication for web applications. When enabled, the JWT token is automatically set as an HttpOnly cookie on successful login, and the authentication system will fall back to the cookie if the Authorization header is missing.

**📖 For detailed web application setup, CORS configuration, and best practices, see the [Cookie Authentication Guide](cookie_authentication_guide.md).**

**To enable cookie authentication**, add the following to your host app's initializer:

```ruby
CommandTower.configure do |config|
  config.jwt.cookie.enabled = true
  # Optional: customize cookie settings
  # config.jwt.cookie.name = "ct_jwt"  # Default: "ct_jwt"
  # config.jwt.cookie.same_site = :lax  # Default: :lax
  # config.jwt.cookie.secure = true     # Default: Rails.env.production?
  # config.jwt.cookie.path = "/"        # Default: "/"
  # config.jwt.cookie.domain = nil      # Default: nil (host-only)

  # Optional: Enable double-submit CSRF protection
  # config.jwt.cookie.csrf.enabled = false  # Default: false
  # config.jwt.cookie.csrf.cookie_name = "ct_csrf"  # Default: "ct_csrf"
  # config.jwt.cookie.csrf.header_name = "X-CSRF-Token"  # Default: "X-CSRF-Token"
  # config.jwt.cookie.csrf.rotate_on_login = true  # Default: true
  # config.jwt.cookie.csrf.rotate_on_reset = true  # Default: true
end
```

**Security considerations:**
- Cookies are HttpOnly by default (not accessible via JavaScript)
- Cookies use SameSite=Lax by default to prevent CSRF attacks
- Optional double-submit CSRF protection can be enabled for additional security (see [Cookie Authentication Guide](cookie_authentication_guide.md))
- Secure flag is automatically set to `true` in production
- Cookie TTL matches the JWT TTL configuration

**Behavior:**
- On successful login, the token is set in both the response header (`X-Authorization-Reset`) and the HttpOnly cookie (if enabled)
- Authentication checks the `Authorization` header first, then falls back to the cookie if the header is missing
- When tokens are refreshed (via `X-Authorization-Reset: true`), the cookie is automatically updated
- Use `POST /auth/logout` to clear the cookie (browser-only logout, does not reset `verifier_token`)

**Token Extraction Priority:**
1. `Authorization: Bearer {token}` header (checked first)
2. HttpOnly cookie (fallback, only if header is missing and cookie auth is enabled)

### How to get the JWT Token
Each Authentication strategy has a `/login` route. This route will return to you a valid token that can then be used for subsequent API Calls

### Regenerate JWT token on the fly
The token can be refreshed in any API call when provided an existing JWT token. To refresh the token, simply add the following Header value to a request:

```
X-Authentication-Reset=true
```

The request will return the following header:
```
X-Authentication-Reset="Regenerated token"
```

**Use Caution** when regenerating the JWT token. While nothing is stopping you from regenerating on every request, it will add some latency that is may not be needed.

**Note:** When cookie authentication is enabled, token refresh automatically updates the cookie as well.

## Encryption
JWT tokens are encrypted at rest. The Encryption key is delivered as the `hmac_secret` in the configuration or set as an ENV variable `SECRET_KEY_BASE`.

## Default JWT Payload's
JWT can hold a payload. This payload is encrypted and is sent as part of the encrypted header

### Expires At
The `expires_at` payload is a timestamp for when the token must be regenerated. After the token "expires", the User will no longer be authenticated to actions and a `401` is returned.

### Verifier Token
Each user has a `verifier_token` encrypted into the payload of the JWT token. This token must match what is on the User's Record. If it does not match, authentication fails. A User or an Admin can reset the verifier token any time they want to log out of all sessions. Authenticated password change (`POST /auth/password/change`) rotates the verifier automatically.
