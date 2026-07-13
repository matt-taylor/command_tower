# Cookie Authentication Guide for Web Applications

This guide explains when and how to use HttpOnly cookie-based JWT authentication in CommandTower, particularly for web applications that need browser-based session persistence.

## Cookie JWT Auth Overview

### What It Does

Cookie-based JWT authentication enables persistence across web reloads without storing JWT tokens in localStorage or sessionStorage. This provides a secure, automatic way to maintain user sessions in browser-based applications.

### How It Works

The authentication system uses a **header-first, cookie fallback** approach:

1. **Authorization Header** (checked first): `Authorization: Bearer {token}`
   - Takes precedence when present
   - Used by mobile apps, API clients, and explicit web requests

2. **HttpOnly Cookie** (fallback): Cookie named `ct_jwt` (configurable)
   - Only checked if Authorization header is missing or empty
   - Automatically sent by browser on subsequent requests
   - HttpOnly flag prevents JavaScript access

3. **Token Refresh**: When `X-Authorization-Reset: true` header is sent, a new JWT is generated and set in both the response header and cookie (if enabled)

### Cookie Name, Flags, and Defaults

- **Cookie Name**: `ct_jwt` (configurable via `config.jwt.cookie.name`)
- **HttpOnly**: `true` (prevents JavaScript access, mitigates XSS)
- **SameSite**: `:lax` (CSRF protection while allowing top-level navigation)
- **Secure**: `false` in development, `true` in production (HTTPS only)
- **Path**: `/` (configurable)
- **Domain**: `nil` by default (host-only), can be set for subdomain sharing
- **TTL**: Matches JWT TTL (default: 7 days, configurable)

## When to Use Cookie vs Header Authentication

### Use Cookie Authentication For:
- **Web Applications**: Single-page applications (SPAs), traditional web apps, or any browser-based application
- **Session Persistence**: When you want users to remain logged in after page refreshes without storing tokens in JavaScript
- **Security**: When you want to prevent XSS attacks by keeping tokens inaccessible to JavaScript (HttpOnly cookies)
- **Automatic Token Management**: When you want the browser to automatically send credentials on each request

### Use Header Authentication For:
- **Mobile Applications**: iOS, Android, or React Native apps that need explicit token management
- **API Clients**: Command-line tools, scripts, or server-to-server communication
- **Microservices**: Service-to-service authentication where cookies aren't appropriate
- **Explicit Control**: When you need full control over when and how tokens are sent

### Hybrid Approach (Recommended for Multi-Platform Apps)
You can enable cookie authentication while still supporting header-based authentication. The system checks headers first, then falls back to cookies. This allows:
- Web browsers to use cookies automatically
- Mobile apps to use Authorization headers
- API clients to use headers explicitly

## Configuration

### Step 1: Enable Cookie Authentication

Add the following to your host app's initializer (`config/initializers/command_tower.rb`):

```ruby
CommandTower.configure do |config|
  # Enable cookie-based authentication
  config.jwt.cookie.enabled = true

  # Optional: Customize cookie settings
  # config.jwt.cookie.name = "ct_jwt"  # Default: "ct_jwt"
  # config.jwt.cookie.same_site = :lax  # Default: :lax (:lax, :strict, or :none)
  # config.jwt.cookie.secure = true     # Default: false (auto-set to true in production)
  # config.jwt.cookie.path = "/"        # Default: "/"
  # config.jwt.cookie.domain = nil      # Default: nil (host-only)
  # config.jwt.cookie.ttl = 7.days      # Default: matches JWT TTL

  # Optional: Enable double-submit CSRF protection for cookie-authenticated requests
  # config.jwt.cookie.csrf.enabled = false  # Default: false (disabled by default)
  # config.jwt.cookie.csrf.cookie_name = "ct_csrf"  # Default: "ct_csrf"
  # config.jwt.cookie.csrf.header_name = "X-CSRF-Token"  # Default: "X-CSRF-Token"
  # config.jwt.cookie.csrf.rotate_on_login = true  # Default: true
  # config.jwt.cookie.csrf.rotate_on_reset = true  # Default: true
end
```

### Configuration Examples

#### Basic Cookie Authentication

```ruby
CommandTower.configure do |config|
  config.jwt.cookie.enabled = true
end
```

#### Cookie Authentication with Custom Domain (for subdomain sharing)

```ruby
CommandTower.configure do |config|
  config.jwt.cookie.enabled = true
  config.jwt.cookie.domain = ".example.com"  # Shared across subdomains
end
```

#### Cookie Authentication with CSRF Protection

```ruby
CommandTower.configure do |config|
  config.jwt.cookie.enabled = true
  config.jwt.cookie.csrf.enabled = true
  config.jwt.cookie.csrf.rotate_on_login = true  # Rotate CSRF token on login
  config.jwt.cookie.csrf.rotate_on_reset = true  # Rotate CSRF token on token refresh
end
```

### Step 2: Configure CORS for Cookie Support

**Critical**: Cookie authentication requires proper CORS configuration. Without this, browsers will block cookie-based requests due to same-origin policy.

#### For Rails Applications

If your Rails app handles CORS, configure it in `config/initializers/cors.rb`:

```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://your-frontend-domain.com',  # Production frontend
            'http://localhost:3000',             # Development frontend
            'http://localhost:5173'              # Vite dev server

    resource '*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options, :head],
      credentials: true  # REQUIRED: Allows cookies to be sent cross-origin
  end
end
```

**⚠️ Important**: If you have an existing CORS configuration that uses `origins: "*"`, you **must** update it to explicitly list origins when enabling cookie authentication. Browsers will reject requests with `credentials: true` if `origins: "*"` is used.

**Before (won't work with cookies)**:
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"  # ❌ Cannot use wildcard with credentials: true

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
      # Missing credentials: true
  end
end
```

**After (works with cookies)**:
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://your-frontend-domain.com',  # ✅ Explicit origins
            'http://localhost:3000',
            'http://localhost:5173'

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true  # ✅ Required for cookies
  end
end
```

**Key CORS Settings for Cookie Authentication**:
- `credentials: true` - **REQUIRED** - Allows cookies to be sent in cross-origin requests
- `origins` - Must explicitly list allowed origins (cannot use `*` when credentials are enabled)
- `headers: :any` - Allows all headers (or specify `['Authorization', 'Content-Type', 'X-Authorization-Reset']`)

#### For CommandTower Engine Only

If CommandTower is the only Rails app and you need to configure CORS:

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins CommandTower.config.app.app_url,  # Use configured app URL
            'http://localhost:3000',          # Development
            'http://localhost:5173'           # Vite

    resource '/command_tower/*',  # Or your mounted path
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options, :head],
      credentials: true
  end
end
```

#### Frontend Configuration

Your frontend HTTP client must also be configured to send credentials:

**Fetch API**:
```javascript
fetch('https://api.example.com/command_tower/user', {
  credentials: 'include',  // REQUIRED: Sends cookies with request
  headers: {
    'Content-Type': 'application/json'
  }
})
```

**Axios**:
```javascript
axios.defaults.withCredentials = true;  // Global setting

// Or per request
axios.get('https://api.example.com/command_tower/user', {
  withCredentials: true
})
```

**XMLHttpRequest**:
```javascript
const xhr = new XMLHttpRequest();
xhr.withCredentials = true;  // REQUIRED
xhr.open('GET', 'https://api.example.com/command_tower/user');
xhr.send();
```

### Step 3: Client Requirements for CSRF Protection (If Enabled)

If you've enabled CSRF protection (`config.jwt.cookie.csrf.enabled = true`), your frontend client must:

1. **Read the CSRF cookie** from `document.cookie`
2. **Send the CSRF token** in the `X-CSRF-Token` header (or configured header name) for unsafe HTTP methods (POST, PUT, PATCH, DELETE)
3. **Handle CSRF errors** appropriately

#### React SPA Example

```javascript
// Helper function to get CSRF token from cookie
function getCsrfToken() {
  const name = 'ct_csrf';
  const cookies = document.cookie.split(';');
  for (let cookie of cookies) {
    const [key, value] = cookie.trim().split('=');
    if (key === name) {
      return decodeURIComponent(value);
    }
  }
  return null;
}

// API client with CSRF support
const apiClient = axios.create({
  baseURL: process.env.REACT_APP_API_URL,
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Add CSRF token to unsafe requests
apiClient.interceptors.request.use((config) => {
  const method = config.method?.toUpperCase();
  if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
    const csrfToken = getCsrfToken();
    if (csrfToken) {
      config.headers['X-CSRF-Token'] = csrfToken;
    }
  }
  return config;
});

// Handle CSRF errors
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 403) {
      const message = error.response.data?.message;
      if (message === 'csrf_missing' || message === 'csrf_mismatch') {
        // Handle CSRF error - could redirect to login or show error
        console.error('CSRF validation failed');
      }
    }
    return Promise.reject(error);
  }
);
```

#### Fetch API Example

```javascript
// Helper function to get CSRF token
function getCsrfToken() {
  const name = 'ct_csrf';
  const match = document.cookie.match(new RegExp('(^| )' + name + '=([^;]+)'));
  return match ? match[2] : null;
}

// Make authenticated request with CSRF token
async function makeRequest(url, options = {}) {
  const method = options.method?.toUpperCase();
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers
  };

  // Add CSRF token for unsafe methods
  if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
    const csrfToken = getCsrfToken();
    if (csrfToken) {
      headers['X-CSRF-Token'] = csrfToken;
    }
  }

  const response = await fetch(url, {
    ...options,
    credentials: 'include',  // REQUIRED for cookies
    headers
  });

  if (!response.ok) {
    const error = await response.json();
    if (response.status === 403 && (error.message === 'csrf_missing' || error.message === 'csrf_mismatch')) {
      // Handle CSRF error
      console.error('CSRF validation failed');
    }
    throw new Error(error.message || 'Request failed');
  }

  return response.json();
}
```

#### Mobile / Service Clients

**Mobile apps and API clients should use Authorization header authentication** instead of cookies:

- Use `Authorization: Bearer {token}` header
- Do NOT send cookies
- CSRF protection does NOT apply to header-authenticated requests
- No CSRF token handling needed

## How It Works

### Authentication Flow

1. **Login Request**:
   ```
   POST /auth/login
   Content-Type: application/json

   {
     "identifier": "user@example.com",
     "password": "password123"
   }
   ```

2. **Login Response** (when cookie auth enabled, CSRF enabled):
   ```
   HTTP/1.1 201 Created
   X-Authorization-Reset: eyJhbGciOiJIUzI1NiJ9...
   X-Authorization-Expire: "2025-01-27 01:42:10 +0000"
   Set-Cookie: ct_jwt=eyJhbGciOiJIUzI1NiJ9...; path=/; expires=Tue, 27 Jan 2026 01:42:10 GMT; httponly; samesite=lax
   Set-Cookie: ct_csrf=6c83347d417802fef533719c5fd41d0b210e9f9aa7a376e50eb0399c93109bd5; path=/; expires=Tue, 27 Jan 2026 01:42:10 GMT; samesite=lax
   Content-Type: application/json

   {
     "token": "eyJhbGciOiJIUzI1NiJ9...",
     "header_name": "Authorization",
     "message": "Successfully logged user in",
     "user": { ... }
   }
   ```

   **Note**: When CSRF protection is enabled, both JWT and CSRF cookies are set on login. The CSRF cookie is NOT HttpOnly (readable by JavaScript).

3. **Subsequent Requests**:
   - Browser automatically includes the cookie in all requests to the same domain
   - No need to manually set Authorization header (though it still works if provided)
   - Token is extracted from cookie if header is missing

### Token Extraction Priority

The authentication system checks in this order:

1. **Authorization Header** (checked first):
   ```
   Authorization: Bearer {token}
   ```
   - If present and valid, uses this token
   - Takes precedence over cookie

2. **HttpOnly Cookie** (fallback):
   - Only checked if Authorization header is missing or empty
   - Only used if cookie authentication is enabled
   - Cookie name is configurable (default: `ct_jwt`)

### Token Refresh

When tokens are refreshed (via `X-Authorization-Reset: true` header):

1. New token is generated
2. Token is set in `X-Authorization-Reset` response header
3. **Cookie is automatically updated** with the new token (if cookie auth enabled)
4. Browser automatically uses the new cookie value on subsequent requests

**Example Refresh Request**:
```
GET /user
Authorization: Bearer {old_token}
X-Authorization-Reset: true
```

**Response** (when CSRF is enabled and `rotate_on_reset = true`):
```
HTTP/1.1 200 OK
X-Authorization-Reset: {new_token}
X-Authorization-Expire: "2025-01-27 02:42:10 +0000"
Set-Cookie: ct_jwt={new_token}; path=/; expires=Tue, 27 Jan 2026 02:42:10 GMT; httponly; samesite=lax
Set-Cookie: ct_csrf={new_csrf_token}; path=/; expires=Tue, 27 Jan 2026 02:42:10 GMT; samesite=lax
```

**Note**: When CSRF protection is enabled and `rotate_on_reset = true`, the CSRF cookie is also rotated on token refresh. If `rotate_on_reset = false`, the CSRF cookie is only created if missing, but not rotated if it already exists.

### Logout

To clear the browser session:

```
POST /auth/logout
Content-Type: application/json
```

**Response**:
```
HTTP/1.1 200 OK
Set-Cookie: ct_jwt=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; httponly; samesite=lax
Content-Type: application/json

{
  "message": "Logged out"
}
```

**Important**: This is a browser-only logout. It does NOT reset the user's `verifier_token`, so tokens used by mobile apps or API clients remain valid. To log out of all sessions, use `POST /user/modify` with `verifier_token: true`.

## Security Considerations

### Cookie Security Features

1. **HttpOnly**: Cookies are HttpOnly by default, preventing JavaScript access
   - This prevents XSS attacks from exfiltrating tokens via JavaScript
   - Tokens cannot be read from `document.cookie` or accessed via JavaScript APIs

2. **SameSite**: Defaults to `Lax` to prevent CSRF attacks while allowing top-level navigation
   - `:lax`: Cookie sent on top-level navigation, not on cross-site POST requests
   - `:strict`: Cookie only sent on same-site requests (stricter CSRF protection)
   - `:none`: Cookie sent on all requests (requires `Secure: true`)

3. **Secure**: Automatically set to `true` in production (HTTPS only)
   - Prevents man-in-the-middle attacks
   - Cookie only transmitted over encrypted connections

4. **Path**: Configurable (default: `/`)
   - Restricts cookie to specific URL paths

5. **Domain**: Configurable (default: `nil` for host-only cookies)
   - Host-only cookies are more secure (not shared across subdomains)
   - Can be set to subdomain (e.g., `".example.com"`) for cross-subdomain sharing

### CSRF Protection (Double-Submit)

Cookie authentication is vulnerable to CSRF (Cross-Site Request Forgery) attacks if not properly protected. CommandTower provides CSRF protection through:

1. **SameSite Cookie Attribute**: The default `SameSite=Lax` setting provides basic CSRF protection by preventing cookies from being sent on cross-site POST requests.

2. **Double-Submit CSRF Protection** (Optional): For additional CSRF protection, you can enable double-submit CSRF tokens. This requires the client to send a CSRF token in both a cookie (automatically sent by the browser) and a custom header (set by JavaScript).

#### How Double-Submit CSRF Works

When CSRF protection is enabled:
- A CSRF token is set in a **non-HttpOnly cookie** (readable by JavaScript)
- The client must read this cookie and send the same token in a custom header (default: `X-CSRF-Token`)
- The server validates that the cookie token matches the header token
- This protection only applies to **cookie-authenticated unsafe HTTP methods** (POST, PUT, PATCH, DELETE)
- **Authorization header authentication is always exempt** from CSRF checks

#### CSRF Enforcement Rules

- **Enabled only when**: CSRF is enabled AND token source is `:cookie` AND HTTP method is unsafe (POST, PUT, PATCH, DELETE)
- **Always exempt**: Authorization header authentication, GET/HEAD/OPTIONS requests
- **Error responses**: Returns `403 Forbidden` with error code `csrf_missing` or `csrf_mismatch`

#### CSRF Cookie Issuance

CSRF cookies are automatically managed:

- **On Login**: CSRF cookie is created/rotated based on `rotate_on_login` setting
  - `rotate_on_login = true`: Always generates a new token
  - `rotate_on_login = false`: Creates cookie if missing, keeps existing if present
- **On Token Reset**: CSRF cookie is created/rotated based on `rotate_on_reset` setting
  - `rotate_on_reset = true`: Always generates a new token
  - `rotate_on_reset = false`: Creates cookie if missing, keeps existing if present
- **On Logout**: CSRF cookie is always cleared (not configurable)

### JWT Token Security

1. **Token Refresh Does Not Revoke Old Tokens**: When a token is refreshed (via `X-Authorization-Reset: true`), a new JWT is generated but the old token remains valid until it expires. This is by design - JWTs are stateless and don't require server-side session storage.

2. **Global Logout**: To log out of all sessions (including mobile apps and API clients), you must reset the user's `verifier_token`:
   ```ruby
   # Via API endpoint (if available)
   POST /user/modify
   { "verifier_token": true }
   ```
   This invalidates all existing JWTs for that user, as they all contain the old `verifier_token` value.

3. **Browser-Only Logout**: The `/auth/logout` endpoint only clears the browser cookie. It does NOT reset `verifier_token`, so tokens used by mobile apps or API clients remain valid.

### Recommended Settings by Environment

**Development**:
```ruby
config.jwt.cookie.enabled = true
config.jwt.cookie.secure = false  # Allow HTTP
config.jwt.cookie.same_site = :lax
```

**Production**:
```ruby
config.jwt.cookie.enabled = true
config.jwt.cookie.secure = true   # HTTPS only (auto-set)
config.jwt.cookie.same_site = :lax  # Or :strict for stricter CSRF protection
# Optional: Enable CSRF protection for additional security
config.jwt.cookie.csrf.enabled = true
```

**Production with CSRF Protection**:
```ruby
config.jwt.cookie.enabled = true
config.jwt.cookie.secure = true
config.jwt.cookie.same_site = :lax
config.jwt.cookie.csrf.enabled = true
config.jwt.cookie.csrf.rotate_on_login = true
config.jwt.cookie.csrf.rotate_on_reset = true
```

**Cross-Domain (Multiple Subdomains)**:
```ruby
config.jwt.cookie.enabled = true
config.jwt.cookie.domain = ".example.com"  # Shared across subdomains
config.jwt.cookie.same_site = :lax
# Optional: Enable CSRF protection
config.jwt.cookie.csrf.enabled = true
```

### CORS Security

- **Never use `origins: '*'`** when `credentials: true` is set
- Always explicitly list allowed origins
- Use HTTPS in production
- Consider using `same_site: :strict` for additional CSRF protection if your app doesn't need cross-site navigation

## Common Patterns

### Pattern 1: SPA with Separate API Domain

**Setup**:
- Frontend: `https://app.example.com`
- Backend: `https://api.example.com`

**CORS Configuration**:
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://app.example.com'

    resource '*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options, :head],
      credentials: true
  end
end
```

**Cookie Configuration**:
```ruby
config.jwt.cookie.domain = ".example.com"  # Shared across subdomains
config.jwt.cookie.same_site = :lax
```

### Pattern 2: Same-Origin Application

**Setup**:
- Frontend and Backend: `https://example.com`

**CORS Configuration**:
```ruby
# CORS not strictly necessary for same-origin, but can be configured
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://example.com'

    resource '*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options, :head],
      credentials: true
  end
end
```

**Cookie Configuration**:
```ruby
config.jwt.cookie.domain = nil  # Host-only (default)
config.jwt.cookie.same_site = :lax
```

### Pattern 3: Development with Hot Reload

**Setup**:
- Frontend Dev Server: `http://localhost:5173` (Vite) or `http://localhost:3000` (Create React App)
- Backend: `http://localhost:7777`

**CORS Configuration**:
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:5173',
            'http://localhost:3000',
            'http://localhost:8080'  # Vue CLI default

    resource '*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options, :head],
      credentials: true
  end
end
```

**Cookie Configuration**:
```ruby
config.jwt.cookie.enabled = true
config.jwt.cookie.secure = false  # Allow HTTP in development
config.jwt.cookie.same_site = :lax
```

## Troubleshooting

### Cookies Not Being Set

**Problem**: Login succeeds but cookie is not set in browser.

**Solutions**:
1. Check that `config.jwt.cookie.enabled = true` is set
2. Verify CORS is configured with `credentials: true`
3. Check browser console for CORS errors
4. Ensure frontend is sending requests with `credentials: 'include'` (Fetch) or `withCredentials: true` (Axios)
5. Verify cookie domain matches your frontend domain (or use subdomain wildcard)

### Cookies Not Being Sent

**Problem**: Cookie is set but not sent with subsequent requests.

**Solutions**:
1. Verify `credentials: 'include'` is set in all fetch requests
2. Check that request URL matches cookie domain/path
3. Ensure cookie hasn't expired
4. Check browser DevTools → Application → Cookies to verify cookie exists
5. Verify CORS allows credentials

### CORS Errors

**Problem**: Browser shows CORS errors when making requests.

**Solutions**:
1. Ensure `credentials: true` is set in CORS configuration
2. Verify `origins` explicitly lists your frontend domain (cannot use `*`)
3. Check that frontend is using `credentials: 'include'` in requests
4. Verify `Access-Control-Allow-Credentials: true` header is present in response
5. Check browser console for specific CORS error messages

### Authentication Fails After Page Refresh

**Problem**: User is logged in but gets 401 after refreshing page.

**Solutions**:
1. Verify cookie is being set (check browser DevTools)
2. Ensure cookie hasn't expired (check cookie expiration)
3. Verify cookie authentication is enabled
4. Check that cookie name matches configuration
5. Ensure CORS allows credentials

### Token Refresh Doesn't Update Cookie

**Problem**: Token is refreshed but cookie still has old value.

**Solutions**:
1. Verify cookie authentication is enabled
2. Check that `X-Authorization-Reset: true` header is being sent
3. Verify response includes `Set-Cookie` header with new token
4. Check browser DevTools → Network tab to see cookie update

### CSRF Errors

**Problem**: Requests return `403 Forbidden` with `csrf_missing` or `csrf_mismatch` error.

**Error: `csrf_missing`**
- **Cause**: CSRF token is missing from either the cookie or the header
- **Solutions**:
  1. Verify CSRF protection is enabled (`config.jwt.cookie.csrf.enabled = true`)
  2. Check that CSRF cookie exists in browser DevTools → Application → Cookies
  3. Verify client is reading CSRF cookie from `document.cookie`
  4. Ensure client is sending `X-CSRF-Token` header (or configured header name) for unsafe methods
  5. Check that CSRF cookie is not HttpOnly (it must be readable by JavaScript)

**Error: `csrf_mismatch`**
- **Cause**: CSRF token in cookie doesn't match the token in the header
- **Solutions**:
  1. Verify client is reading the correct CSRF cookie value
  2. Ensure the same token value is sent in both cookie and header
  3. Check for token encoding/decoding issues
  4. Verify CSRF cookie hasn't been rotated (e.g., after login) without updating the header value

**General CSRF Troubleshooting**:
- CSRF protection only applies to cookie-authenticated unsafe methods (POST, PUT, PATCH, DELETE)
- Authorization header authentication is always exempt from CSRF checks
- GET/HEAD/OPTIONS requests never require CSRF tokens
- Verify CSRF cookie is set after login (check `Set-Cookie` header in login response)

## Best Practices

1. **Always Use HTTPS in Production**: Cookies with `Secure` flag require HTTPS
2. **Explicit Origins**: Never use `origins: '*'` with `credentials: true`
3. **Monitor Cookie Expiration**: Set up client-side logic to refresh tokens before expiration
4. **Handle Logout Properly**: Use `/auth/logout` for browser sessions, `verifier_token: true` for all sessions
5. **Test Cross-Origin**: Test your CORS configuration in development with different origins
6. **Use SameSite=Lax**: Provides good balance of security and functionality
7. **Monitor Security Headers**: Ensure your application sets appropriate security headers
8. **Enable CSRF Protection for Web Apps**: For production web applications, enable double-submit CSRF protection for additional security beyond SameSite cookies
9. **Test CSRF Flow**: Verify CSRF token is read correctly and sent in headers for all unsafe methods
10. **Handle CSRF Errors Gracefully**: Implement proper error handling for `csrf_missing` and `csrf_mismatch` errors

## Migration from Header-Only to Cookie Support

If you're migrating an existing application:

1. **Enable Cookie Auth** (non-breaking):
   ```ruby
   config.jwt.cookie.enabled = true
   ```
   - Existing header-based clients continue to work
   - Cookies are set as additional authentication method

2. **Update Frontend**:
   - Add `credentials: 'include'` to all fetch requests
   - Remove manual token storage/retrieval from localStorage
   - Update login flow to rely on automatic cookie handling

3. **Configure CORS**:
   - Add CORS middleware with `credentials: true`
   - List allowed origins explicitly

4. **Test Both Methods**:
   - Verify header authentication still works (for mobile/API clients)
   - Verify cookie authentication works (for web clients)

## Example: Complete Setup

### Backend Configuration

```ruby
# config/initializers/command_tower.rb
CommandTower.configure do |config|
  config.jwt.cookie.enabled = true
  config.jwt.cookie.name = "ct_jwt"
  config.jwt.cookie.same_site = :lax
  config.jwt.cookie.secure = Rails.env.production?
  config.jwt.cookie.path = "/"
end

# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Rails.env.production? ?
              ['https://app.example.com'] :
              ['http://localhost:3000', 'http://localhost:5173']

    resource '*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options, :head],
      credentials: true
  end
end
```

### Frontend Configuration (React Example)

```javascript
// api/client.js
import axios from 'axios';

const apiClient = axios.create({
  baseURL: process.env.REACT_APP_API_URL,
  withCredentials: true,  // REQUIRED for cookies
  headers: {
    'Content-Type': 'application/json'
  }
});

// Login
export const login = async (identifier, password) => {
  const response = await apiClient.post('/auth/login', {
    identifier,
    password
  });
  // Cookie is automatically set by browser
  // Token is also in response.data.token if needed
  return response.data;
};

// Logout
export const logout = async () => {
  await apiClient.post('/auth/logout');
  // Cookie is automatically cleared by browser
};

// Authenticated request (cookie sent automatically)
export const getCurrentUser = async () => {
  const response = await apiClient.get('/user');
  return response.data;
};
```

## Integration Expectations

### Host App CORS Configuration

**Host applications must configure CORS** to allow credentials and expose refresh headers. This is a requirement for cookie authentication to work in cross-origin scenarios.

**Required CORS Settings**:
- `credentials: true` - **REQUIRED** - Allows cookies to be sent cross-origin
- `origins` - Must explicitly list allowed origins (cannot use `*` when credentials are enabled)
- `headers` - Must allow `Authorization`, `X-Authorization-Reset`, and `Content-Type` headers
- `exposed_headers` - Should expose `X-Authorization-Reset` and `X-Authorization-Expire` headers

**Note**: CommandTower does not configure CORS automatically. Host apps must configure CORS middleware (e.g., `Rack::Cors`) in their initializers. See the [Configuration](#step-2-configure-cors-for-cookie-support) section for examples.

### SPA Token Storage

**When cookie mode is enabled, SPAs should NOT store JWT tokens in localStorage or sessionStorage.**

- Cookies are automatically managed by the browser
- Storing tokens in localStorage defeats the security benefits of HttpOnly cookies
- If you need token access in JavaScript (not recommended), use the `X-Authorization-Reset` response header, but be aware this reduces security

**Best Practice**: Rely entirely on cookies for web applications. Only use header-based authentication for mobile apps and API clients.

### Automatic Cookie Management

The browser automatically:
- Sends cookies with every request to the same domain
- Updates cookies when `Set-Cookie` headers are received
- Clears cookies when expiration is set in the past

**No JavaScript code is needed** to manage cookies when using HttpOnly cookies.

### Token Refresh Headers

When token refresh is requested (via `X-Authorization-Reset: true` header), the response includes:
- `X-Authorization-Reset`: New JWT token (for header-based clients)
- `X-Authorization-Expire`: Token expiration timestamp
- `Set-Cookie`: Updated cookie with new token (if cookie auth enabled)

**Frontend clients should**:
- Monitor the `X-Authorization-Expire` header to know when to refresh
- Send `X-Authorization-Reset: true` header before token expiration
- Update stored tokens (if using header auth) from `X-Authorization-Reset` header
- Let the browser handle cookie updates automatically

## Summary

Cookie authentication provides a secure, convenient way to handle JWT tokens in web applications:

- **Automatic**: Browser handles cookie sending/receiving
- **Secure**: HttpOnly cookies prevent XSS attacks
- **Persistent**: Survives page refreshes
- **Flexible**: Works alongside header authentication

Remember to:
- Enable cookie authentication in configuration
- Configure CORS with `credentials: true` (host app responsibility)
- Set frontend to send credentials
- Do NOT store JWT tokens in localStorage when cookie mode is enabled
- If using CSRF protection, ensure client reads CSRF cookie and sends it in headers for unsafe methods
- Test in both development and production environments

## Enabling CSRF Protection

### Step 1: Enable CSRF in Configuration

Add the following to your host app's initializer (`config/initializers/command_tower.rb`):

```ruby
CommandTower.configure do |config|
  # Enable cookie authentication (required for CSRF)
  config.jwt.cookie.enabled = true

  # Enable CSRF protection
  config.jwt.cookie.csrf.enabled = true

  # Optional: Configure CSRF behavior
  # config.jwt.cookie.csrf.cookie_name = "ct_csrf"  # Default: "ct_csrf"
  # config.jwt.cookie.csrf.header_name = "X-CSRF-Token"  # Default: "X-CSRF-Token"
  # config.jwt.cookie.csrf.rotate_on_login = true  # Default: true (always rotate on login)
  # config.jwt.cookie.csrf.rotate_on_reset = true  # Default: true (always rotate on token reset)
end
```

### Step 2: Update Frontend Client

Your frontend must:
1. Read the CSRF cookie from `document.cookie` after login
2. Send the CSRF token in the `X-CSRF-Token` header for all unsafe HTTP methods (POST, PUT, PATCH, DELETE)
3. Handle CSRF errors appropriately

See the [Client Requirements for CSRF Protection](#step-3-client-requirements-for-csrf-protection-if-enabled) section above for complete frontend implementation examples.

### Step 3: Verify CSRF Cookie is Set

After login, check that the CSRF cookie is present:
- Browser DevTools → Application → Cookies → Look for `ct_csrf` cookie
- The cookie should NOT have the HttpOnly flag (must be readable by JavaScript)
- The cookie should have the same path, domain, and secure settings as the JWT cookie

### Step 4: Test CSRF Protection

1. **Test with missing CSRF header**: Make a POST request without the `X-CSRF-Token` header → Should return `403 Forbidden` with `csrf_missing`
2. **Test with mismatched tokens**: Set different values in cookie and header → Should return `403 Forbidden` with `csrf_mismatch`
3. **Test with matching tokens**: Set same value in cookie and header → Should succeed
4. **Test header auth exemption**: Use `Authorization: Bearer {token}` header → Should succeed without CSRF token

### CSRF Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `csrf.enabled` | `false` | Enable/disable CSRF protection |
| `csrf.cookie_name` | `"ct_csrf"` | Name of the CSRF cookie (must NOT be HttpOnly) |
| `csrf.header_name` | `"X-CSRF-Token"` | Name of the CSRF token header |
| `csrf.rotate_on_login` | `true` | Always generate new CSRF token on login |
| `csrf.rotate_on_reset` | `true` | Always generate new CSRF token on token refresh |
| `csrf.same_site` | `nil` (inherits from JWT cookie) | SameSite attribute for CSRF cookie |
| `csrf.secure` | `nil` (inherits from JWT cookie) | Secure flag for CSRF cookie |
| `csrf.path` | `nil` (inherits from JWT cookie) | Path for CSRF cookie |
| `csrf.domain` | `nil` (inherits from JWT cookie) | Domain for CSRF cookie |
| `csrf.ttl` | `7.days` | Time to live for CSRF cookie |

**Note**: When CSRF cookie attributes (`same_site`, `secure`, `path`, `domain`) are set to `nil`, they inherit from the JWT cookie configuration. This ensures consistent cookie behavior across your application.
