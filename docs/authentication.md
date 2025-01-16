# Authentication

Authentication is backed by JWT tokens. There are many options to the JWT configuration. Check out [Initializing](initializing.md) to understand where to find the config.

## Usage
Authenticating a User is straightforward via Rails actions. In each controller that you want to authenticate, add the following
```ruby
before_action :authenticate_user!
```

This action will authenticate the user and set `current_user` to the user passed in via the JWT token.

Every API request will return a header that indicates when the current token will expire:
```
X-Authentication-Expire="2025-01-16 04:36:29 +0000"
```

### Header Token
For routes that expect user authentication, the client must set the Header value:
```
Authentication="Bearer: {token value}"
```

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

## Encryption
JWT tokens are encrypted at rest. The Encryption key is delivered as the `hmac_secret` in the configuration or set as an ENV variable `SECRET_KEY_BASE`.

## Default JWT Payload's
JWT can hold a payload. This payload is encrypted and is sent as part of the encrypted header

### Expires At
The `expires_at` payload is a timestamp for when the token must be regenerated. After the token "expires", the User will no longer be authenticated to actions and a `401` is returned.

### Verifier Token
Each user has a `verifier_token` encrypted into the payload of the JWT token. This token must match what is on the User's Record. If it does not match, a 403 is returned. A User or and Admin can reset the versifier token any time they want to log out of all sessions.
