# Authentication

Authentication is backed by JWT tokens. There are many options to the JWT configuration. Check out [Initializing](initializing.md) to understand where to find the config.

## Encryption
JWT tokens are encrypted at rest. The Encryption key is delivered as the `hmac_secret` in the configuration or set as an ENV variable `SECRET_KEY_BASE`.

## Default JWT Payload's
JWT can hold a payload. This payload is encrypted and is sent as part of the encrypted header

### Expires At
The `expires_at` payload is a timestamp for when the token must be regenerated. After the token "expires", the User will no longer be authenticated to actions and a `401` is returned.

### Verifier Token
Each user has a `verifier_token` encrypted into the payload of the JWT token. This token must match what is on the User's Record. If it does not match, a 403 is returned. A User or and Admin can reset the versifier token any time they want to log out of all sessions.
