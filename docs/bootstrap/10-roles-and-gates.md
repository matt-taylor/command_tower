# 10 — Roles and feature gates

## Purpose

Assign the default membership role (if you did not in step 09) and **enable** the HTTP gates the smoke path needs. Gates default **off** → **404**.

## Prerequisites

- [`09-rbac.md`](09-rbac.md)

## Files the host edits

`config/initializers/command_tower.rb`

Opening a `with_*` block typically sets its enable flag. Still set `enable` / `enabled` explicitly so a later comment-uncomment does not leave you on the default **off** path.

## Procedure

### Default role

```ruby
config.authorization.default_membership_role = "member"
```

### Login / verify / reset (minimum for Me + CT frontend guest screens)

```ruby
config.login.with_plain_text do |plain_text_config|
  plain_text_config.enable = true

  plain_text_config.with_email_verify do |email_verify_config|
    email_verify_config.enable = true
    # Curl smoke (step 12) can login before the user verifies.
    # 0.minutes → GET /me is 412 until email is verified.
    email_verify_config.verify_email_required_within = 7.days
  end

  plain_text_config.with_password_reset do |password_reset_config|
    password_reset_config.enabled = true
  end
end
```

### Availability (CT frontend signup)

If the guest signup screen checks username/email availability, enable those gates or the client sees **404**:

```ruby
config.username.with_realtime_username_check do |realtime_username_check_config|
  realtime_username_check_config.enable = true
end

config.signup_session.email_availability.enable = true
```

Leave Admin and messaging gates off until you need those routes.

Do not use role-**name** checks in host code for authorization. Use entity grants / `allow_everything`. See [`../authorization.md`](../authorization.md).

## Stop

Plain-text login is **on**. Register → login → `GET /me` is not **404**. Next: [`11-auth-client-path.md`](11-auth-client-path.md).
