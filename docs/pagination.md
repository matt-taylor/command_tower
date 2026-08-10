# Pagination

CommandTower exposes one live HTTP list contract that returns pagination metadata: **Me Inbox**.

Back to [README](../README.md).

## Me Inbox list contract

`GET /me/inbox` accepts query parameters:

| Param | Default | Notes |
|-------|---------|--------|
| `limit` | `50` | Max `100` |
| `offset` | `0` | |
| `scope` | `"inbox"` | `"inbox"` or `"archived"` |

Success envelope `meta`:

```json
{
  "limit": 50,
  "offset": 0,
  "totalCount": 123
}
```

`data` is an array of inbox items. Full route table: [API reference — Me Inbox](api_reference.md#me-inbox).

Deserializer: `CommandTower::Deserializers::Messaging::Inbox::ListDeserializer`.

## Global pagination config

`CommandTower.config.pagination.limit` defaults to **10**. That value is a generic configuration default for pagination helpers — it is **not** the Me Inbox HTTP default (Inbox uses 50).

```ruby
CommandTower.configure do |c|
  c.pagination.limit = 50
end
```

There is no engine admin list endpoint and no `pagination=true` / `page` / `cursor` query API on current engine HTTP surfaces.

## Related

- [API reference](api_reference.md)
- [Messaging](messaging_integration_guide.md)
- [Controllers](controllers.md)
