# Pagination

Pagination allows a subset of information to be returned.

## Configuration

Default configuration for everything is 10 unless otherwise configured or inputted. This value is changeable but it may come with a latency cost of how much data goes over the wire at once.

### Default configuration

Pagination Default configuration is available as part of the standard CommandTower Configuration.
```ruby
CommandTower.configure do |c|
  # Default is 10 when running the initialization.
  c.pagination.limit = 50
end
```


## Usage

### As a Controller
The [PaginationHelper](
../app/helpers/command_tower/pagination_helper.rb) helps convert user input into what the [PaginationServiceHelper](
../app/services/command_tower/pagination_service_helper.rb) expects.

#### From the Query (Preferred)
Go ahead and throw the values in the query! Pagination can help with handle that.

To send as part of the query, the following parameters are used:

`pagination=true`: This is a required Parameter. When not present, pagination via Query will not be used.

- `limit=<Integer>`
- `page=<Integer>`
- `cursor=<Integer>` (Takes precedence over page)


#### From the Body
Prefer to send it as part of that body? Thats cool. Use this with caution as some Proxies may drop body parameters from GET requests.

To send as part of the body, send in a hash with the key `pagination`
```
{
  key1: 1,
  key2: 2,
  pagination: {
    page:,
    limit:,
    cursor:,
  }
}
```

##### Examples
- [CommandTower::Inbox::MessageController#metadata](../app/controllers/command_tower/inbox/message_controller.rb)
- [CommandTower::AdminController#show](../app/controllers/command_tower/admin_controller.rb)

### As a Service Base
The [PaginationServiceHelper](
../app/services/command_tower/pagination_service_helper.rb) is the the heavy lifter for all pagination in CommandTower.

It is expected to get used from within a [CommandTower::ServiceBase](../app/services/command_tower/README.md) Object.

#### Required Params
Pagination values must be passed in as part of the context within a `pagination` hash.

**pagination.limit**
```
Type: Integer
Required: False -- Falls back to default pagination limit configured
What: The max limit of records returned from the ServiceBase
```

**pagination.cursor**
```
Type: Integer
Required: False -- Recommended page or cursor
What: The starting offset in the database to return objects from. This value takes precedence over `page`
```

**pagination.page**
```
Type: Integer
Required: False -- Recommended page or cursor
What: Based on the limit, the starting page will calculate an offset to return objects from.
```

#### Service accessibility

**Included in Service**: The [PaginationServiceHelper](
../app/services/command_tower/pagination_service_helper.rb) must be included in your ServiceBase for pagination to function

**Default Query Method**: In the ServiceBase, `default_query` must be set. This method should return a new query for your pagination needs. It should include any additional `where` or `select` clauses required for your object.

**Pagination Schema Returned**: For added help, PaginationServiceHelper provides a `pagination_schema` method that returns a [Pagination](../lib/command_tower/schema/pagination.rb). This object can help your user better understand where they are in the page definition and what to call next

```ruby
class BasicExample < CommandTower::ServiceBase
  include CommandTower::PaginationServiceHelper

  def call
    context.query = query
    context.pagination
  end

  def default_query
    Users.all
  end
end
```

#### Service Examples:

- [CommandTower::AdminService::Users](../app/services/command_tower/admin_service/users.rb)

- [CommandTower::InboxService::Message::Metadata](../app/services/command_tower/inbox_service/message/metadata.rb)

