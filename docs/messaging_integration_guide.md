# Command Tower Messaging Integration Guide

This guide provides comprehensive information for integrating Single Page Applications (SPAs) and mobile applications with Command Tower's messaging system.

## Table of Contents

1. [Overview](#overview)
2. [Authentication & Authorization](#authentication--authorization)
3. [Messages vs Message Blasts](#messages-vs-message-blasts)
4. [Message Endpoints](#message-endpoints)
5. [Message Blast Endpoints](#message-blast-endpoints)
6. [Pagination](#pagination)
7. [Error Handling](#error-handling)
8. [CSRF Protection](#csrf-protection)
9. [Token Management](#token-management)

---

## Overview

Command Tower provides a messaging system that allows:
- **Users** to receive and manage individual messages in their inbox
- **Administrators** to create and manage message blasts that are delivered to multiple users

All messaging endpoints require authentication via JWT tokens. Some endpoints (message blasts) also require authorization (admin role).

---

## Authentication & Authorization

### JWT Token Authentication

All messaging endpoints require a valid JWT token. The token must be included in the request headers.

#### Header-Based Authentication (Recommended for SPAs)

Include the JWT token in the `Authorization` header:

```
Authorization: Bearer <your-jwt-token>
```

**Example:**
```javascript
fetch('https://api.example.com/inbox/messages', {
  headers: {
    'Authorization': `Bearer ${jwtToken}`,
    'Content-Type': 'application/json'
  }
})
```

#### Cookie-Based Authentication (Alternative)

If cookie-based authentication is enabled in Command Tower, the JWT token can be stored in an HttpOnly cookie. The system will automatically read the token from the cookie if the `Authorization` header is not present.

**Important:** When using cookie-based authentication, CSRF protection is required for unsafe HTTP methods (POST, PATCH, DELETE). See [CSRF Protection](#csrf-protection) section.

### Authorization

- **Messages**: Any authenticated user can access their own messages
- **Message Blasts**: Requires admin role authorization. Unauthorized requests return `403 Forbidden`

### Authentication Errors

- **401 Unauthorized**: Invalid or missing JWT token
- **403 Forbidden**: Valid token but insufficient permissions (for message blast endpoints)
- **412 Precondition Failed**: Valid token but email verification required

---

## Messages vs Message Blasts

### Messages

**Messages** are individual user-specific notifications in a user's inbox. Each message:
- Belongs to a specific user
- Can be associated with a message blast (optional)
- Has properties: `id`, `title`, `text`, `viewed`, `created_at`
- Can be marked as viewed (acknowledged) or deleted
- Automatically marked as `viewed: true` when retrieved individually

**Key Characteristics:**
- User-scoped: Users can only see and manage their own messages
- Individual operations: Each message is a separate record
- View tracking: Messages have a `viewed` boolean flag

### Message Blasts

**Message Blasts** are templates for broadcasting messages to multiple users. They:
- Are created by administrators
- Define target audiences (`existing_users`, `new_users` flags)
- Generate individual `Message` records for each target user when created
- Can be modified or deleted (which affects all associated messages)
- Have properties: `id`, `title`, `text`, `existing_users`, `new_users`, `created_at`, `created_by`

**Key Characteristics:**
- Admin-only: Only users with admin role can create/manage blasts
- Broadcast mechanism: Creating a blast generates messages for target users
- Template-like: Blasts define the content that gets delivered to users

**Relationship:**
```
MessageBlast (1) ──→ (many) Messages
```

When a message blast is created with `existing_users: true` and/or `new_users: true`, the system automatically creates individual `Message` records for all matching users.

---

## Message Endpoints

### GET /inbox/messages

Retrieves a paginated list of messages for the authenticated user.

**Authentication:** Required (JWT token)

**Authorization:** User can only see their own messages

**Query Parameters (Pagination):**
- `pagination=true` (required to enable query-based pagination)
- `page=<integer>` (optional) - Page number (1-indexed)
- `limit=<integer>` (optional) - Items per page (default: 10)
- `cursor=<integer>` (optional) - Cursor-based pagination (takes precedence over `page`)

**Request Body (Alternative Pagination):**
```json
{
  "pagination": {
    "page": 2,
    "limit": 20,
    "cursor": 15
  }
}
```

**Response (200 OK):**
```json
{
  "count": 10,
  "entities": [
    {
      "id": 1,
      "title": "Welcome Message",
      "viewed": false
    },
    {
      "id": 2,
      "title": "System Update",
      "viewed": true
    }
  ],
  "pagination": {
    "current": {
      "cursor": 0,
      "limit": 10,
      "query": "?pagination=true&page=1&limit=10"
    },
    "next": {
      "cursor": 10,
      "limit": 10,
      "query": "?pagination=true&page=2&limit=10"
    },
    "current_page": 1,
    "remaining_pages": 2,
    "total_pages": 3,
    "count_available": 25
  }
}
```

**Response Fields:**
- `count`: Number of messages in the current page
- `entities`: Array of message objects (without `text` field for list view)
- `pagination`: Pagination metadata (see [Pagination](#pagination) section)

**Example Request:**
```javascript
// Using query parameters
const response = await fetch('https://api.example.com/inbox/messages?pagination=true&page=1&limit=20', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
});

// Using request body
const response = await fetch('https://api.example.com/inbox/messages', {
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    pagination: {
      page: 1,
      limit: 20
    }
  })
});
```

---

### GET /inbox/messages/:id

Retrieves a single message by ID. **Automatically marks the message as viewed** when retrieved.

**Authentication:** Required (JWT token)

**Authorization:** User can only retrieve their own messages

**URL Parameters:**
- `id` (integer) - Message ID

**Response (200 OK):**
```json
{
  "id": 1,
  "title": "Welcome Message",
  "text": "Welcome to our platform! We're excited to have you.",
  "viewed": true
}
```

**Response Fields:**
- `id`: Message ID
- `title`: Message title
- `text`: Full message content (only available in individual message view)
- `viewed`: Boolean indicating if message has been viewed (always `true` after retrieval)

**Error Responses:**
- `400 Bad Request`: Message ID not found for user
  ```json
  {
    "status": "400",
    "message": "Message ID not found for user",
    "invalid_argument_hash": {
      "id": "Message ID not found for user"
    }
  }
  ```

**Example Request:**
```javascript
const response = await fetch(`https://api.example.com/inbox/messages/${messageId}`, {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
});

const message = await response.json();
```

---

### POST /inbox/messages/ack

Marks one or more messages as viewed (acknowledged).

**Authentication:** Required (JWT token)

**Authorization:** User can only acknowledge their own messages

**CSRF Protection:** Required if using cookie-based authentication

**Request Body:**
```json
{
  "ids": [1, 2, 3, 4, 5]
}
```

**Response (200 OK):**
```json
{
  "type": "viewed",
  "ids": [1, 2, 3, 4, 5],
  "count": 5
}
```

**Response Fields:**
- `type`: Always `"viewed"` for ack endpoint
- `ids`: Array of message IDs that were successfully marked as viewed
- `count`: Number of messages that were modified

**Behavior:**
- Only processes message IDs that belong to the authenticated user
- Unknown IDs or IDs belonging to other users are silently ignored
- Returns success even if some IDs are invalid (only valid IDs are processed)

**Error Responses:**
- `400 Bad Request`: No valid IDs found
  ```json
  {
    "status": "400",
    "message": "No ID's found for user",
    "invalid_argument_hash": {
      "ids": "No ID's found for user"
    }
  }
  ```

**Example Request:**
```javascript
const response = await fetch('https://api.example.com/inbox/messages/ack', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
    'X-CSRF-Token': csrfToken  // Required if using cookie auth
  },
  body: JSON.stringify({
    ids: [1, 2, 3, 4, 5]
  })
});
```

---

### POST /inbox/messages/delete

Deletes one or more messages.

**Authentication:** Required (JWT token)

**Authorization:** User can only delete their own messages

**CSRF Protection:** Required if using cookie-based authentication

**Request Body:**
```json
{
  "ids": [1, 2, 3]
}
```

**Response (200 OK):**
```json
{
  "type": "delete",
  "ids": [1, 2, 3],
  "count": 3
}
```

**Response Fields:**
- `type`: Always `"delete"` for delete endpoint
- `ids`: Array of message IDs that were successfully deleted
- `count`: Number of messages that were deleted

**Behavior:**
- Only processes message IDs that belong to the authenticated user
- Unknown IDs or IDs belonging to other users are silently ignored
- Returns success even if some IDs are invalid (only valid IDs are processed)

**Error Responses:**
- `400 Bad Request`: No valid IDs found
  ```json
  {
    "status": "400",
    "message": "No ID's found for user",
    "invalid_argument_hash": {
      "ids": "No ID's found for user"
    }
  }
  ```

**Example Request:**
```javascript
const response = await fetch('https://api.example.com/inbox/messages/delete', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
    'X-CSRF-Token': csrfToken  // Required if using cookie auth
  },
  body: JSON.stringify({
    ids: [1, 2, 3]
  })
});
```

---

## Message Blast Endpoints

All message blast endpoints require **admin role authorization** in addition to authentication.

### GET /inbox/blast

Retrieves metadata about all message blasts (list view with pagination).

**Authentication:** Required (JWT token)

**Authorization:** Admin role required

**Query Parameters (Pagination):**
- `pagination=true` (required to enable query-based pagination)
- `page=<integer>` (optional)
- `limit=<integer>` (optional)
- `cursor=<integer>` (optional)

**Response (200 OK):**
```json
{
  "count": 5,
  "entities": [
    {
      "id": 1,
      "title": "System Maintenance Notice",
      "existing_users": true,
      "new_users": false,
      "created_by": {
        "id": 1,
        "username": "admin"
      }
    }
  ],
  "pagination": {
    "current": {
      "cursor": 0,
      "limit": 10,
      "query": "?pagination=true&page=1&limit=10"
    },
    "next": {
      "cursor": 10,
      "limit": 10,
      "query": "?pagination=true&page=2&limit=10"
    },
    "current_page": 1,
    "remaining_pages": 0,
    "total_pages": 1,
    "count_available": 5
  }
}
```

**Response Fields:**
- `count`: Number of blasts in current page
- `entities`: Array of message blast objects (may not include full `text` for performance)
- `pagination`: Pagination metadata

**Error Responses:**
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Valid token but user lacks admin role

**Example Request:**
```javascript
const response = await fetch('https://api.example.com/inbox/blast?pagination=true&page=1', {
  headers: {
    'Authorization': `Bearer ${adminToken}`,
    'Content-Type': 'application/json'
  }
});
```

---

### GET /inbox/blast/:id

Retrieves a single message blast by ID.

**Authentication:** Required (JWT token)

**Authorization:** Admin role required

**URL Parameters:**
- `id` (integer) - Message Blast ID

**Response (200 OK):**
```json
{
  "id": 1,
  "title": "System Maintenance Notice",
  "text": "We will be performing system maintenance on...",
  "existing_users": true,
  "new_users": false,
  "created_by": {
    "id": 1,
    "username": "admin"
  }
}
```

**Response Fields:**
- `id`: Message Blast ID
- `title`: Blast title
- `text`: Full blast content
- `existing_users`: Boolean - whether to send to existing users
- `new_users`: Boolean - whether to send to new users
- `created_by`: User object who created the blast (optional field)

**Error Responses:**
- `400 Bad Request`: Message Blast ID not found
  ```json
  {
    "status": "400",
    "message": "MessageBlast ID not found",
    "invalid_argument_hash": {
      "id": "MessageBlast ID not found"
    }
  }
  ```
- `403 Forbidden`: User lacks admin role

**Example Request:**
```javascript
const response = await fetch(`https://api.example.com/inbox/blast/${blastId}`, {
  headers: {
    'Authorization': `Bearer ${adminToken}`,
    'Content-Type': 'application/json'
  }
});
```

---

### POST /inbox/blast

Creates a new message blast. This will automatically generate individual messages for all target users.

**Authentication:** Required (JWT token)

**Authorization:** Admin role required

**CSRF Protection:** Required if using cookie-based authentication

**Request Body:**
```json
{
  "title": "Welcome New Users",
  "text": "Welcome to our platform! We're excited to have you join us.",
  "existing_users": false,
  "new_users": true
}
```

**Request Fields:**
- `title` (string, required) - Blast title
- `text` (string, optional) - Blast content
- `existing_users` (boolean, optional) - Send to existing users (default: `false`)
- `new_users` (boolean, optional) - Send to new users (default: `false`)

**Response (200 OK):**
```json
{
  "id": 5,
  "title": "Welcome New Users",
  "text": "Welcome to our platform! We're excited to have you join us.",
  "existing_users": false,
  "new_users": true
}
```

**Response Fields:**
- Same as request fields plus `id` (the newly created blast ID)

**Behavior:**
- Creates the message blast record
- Automatically generates individual `Message` records for all users matching the criteria (`existing_users` and/or `new_users`)
- Returns the created blast with its assigned ID

**Error Responses:**
- `400 Bad Request`: Invalid parameters
  ```json
  {
    "status": "400",
    "message": "Parameter [title] is required but not present",
    "invalid_argument_hash": {
      "title": "Parameter [title] is required but not present"
    }
  }
  ```
- `403 Forbidden`: User lacks admin role

**Example Request:**
```javascript
const response = await fetch('https://api.example.com/inbox/blast', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${adminToken}`,
    'Content-Type': 'application/json',
    'X-CSRF-Token': csrfToken  // Required if using cookie auth
  },
  body: JSON.stringify({
    title: 'Welcome New Users',
    text: 'Welcome to our platform!',
    existing_users: false,
    new_users: true
  })
});
```

---

### PATCH /inbox/blast/:id

Updates an existing message blast.

**Authentication:** Required (JWT token)

**Authorization:** Admin role required

**CSRF Protection:** Required if using cookie-based authentication

**URL Parameters:**
- `id` (integer) - Message Blast ID

**Request Body:**
```json
{
  "title": "Updated Welcome Message",
  "text": "Updated content here...",
  "existing_users": true,
  "new_users": true
}
```

**Request Fields:**
- All fields are optional (only include fields you want to update)
- `title` (string, optional)
- `text` (string, optional)
- `existing_users` (boolean, optional)
- `new_users` (boolean, optional)

**Response (200 OK):**
```json
{
  "id": 5,
  "title": "Updated Welcome Message",
  "text": "Updated content here...",
  "existing_users": true,
  "new_users": true
}
```

**Response Fields:**
- Same structure as create response

**Error Responses:**
- `400 Bad Request`: Invalid parameters or ID not found
- `403 Forbidden`: User lacks admin role

**Example Request:**
```javascript
const response = await fetch(`https://api.example.com/inbox/blast/${blastId}`, {
  method: 'PATCH',
  headers: {
    'Authorization': `Bearer ${adminToken}`,
    'Content-Type': 'application/json',
    'X-CSRF-Token': csrfToken  // Required if using cookie auth
  },
  body: JSON.stringify({
    title: 'Updated Title',
    text: 'Updated content'
  })
});
```

---

### DELETE /inbox/blast/:id

Deletes a message blast.

**Authentication:** Required (JWT token)

**Authorization:** Admin role required

**CSRF Protection:** Required if using cookie-based authentication

**URL Parameters:**
- `id` (integer) - Message Blast ID

**Response (200 OK):**
```json
{
  "id": 5,
  "msg": "Message Blast message deleted"
}
```

**Error Responses:**
- `400 Bad Request`: Message Blast ID not found
  ```json
  {
    "status": "400",
    "message": "MessageBlast ID not found",
    "invalid_argument_hash": {
      "id": "MessageBlast ID not found"
    }
  }
  ```
- `403 Forbidden`: User lacks admin role

**Example Request:**
```javascript
const response = await fetch(`https://api.example.com/inbox/blast/${blastId}`, {
  method: 'DELETE',
  headers: {
    'Authorization': `Bearer ${adminToken}`,
    'Content-Type': 'application/json',
    'X-CSRF-Token': csrfToken  // Required if using cookie auth
  }
});
```

---

## Pagination

Pagination is available on list endpoints (`GET /inbox/messages` and `GET /inbox/blast`). Command Tower supports three pagination methods:

### Pagination Methods

1. **Page-based**: Uses page numbers (1-indexed)
2. **Limit-based**: Controls how many items per page
3. **Cursor-based**: Uses cursor/offset values (takes precedence over page)

### Pagination Parameters

**Via Query String (Preferred):**
```
GET /inbox/messages?pagination=true&page=2&limit=20
```

- `pagination=true` (required) - Enables query-based pagination
- `page=<integer>` (optional) - Page number
- `limit=<integer>` (optional) - Items per page (default: 10)
- `cursor=<integer>` (optional) - Cursor offset (takes precedence over `page`)

**Via Request Body:**
```json
{
  "pagination": {
    "page": 2,
    "limit": 20,
    "cursor": 15
  }
}
```

**Note:** If both `page` and `cursor` are provided, `cursor` takes precedence.

### Pagination Response

The pagination response includes:

```json
{
  "pagination": {
    "current": {
      "cursor": 0,
      "limit": 10,
      "query": "?pagination=true&page=1&limit=10"
    },
    "next": {
      "cursor": 10,
      "limit": 10,
      "query": "?pagination=true&page=2&limit=10"
    },
    "current_page": 1,
    "remaining_pages": 2,
    "total_pages": 3,
    "count_available": 25
  }
}
```

**Response Fields:**
- `current`: Current page information
  - `cursor`: Current cursor/offset value
  - `limit`: Items per page
  - `query`: Ready-to-use query string for current page
- `next`: Next page information (null if on last page)
  - Same structure as `current`
- `current_page`: Current page number (1-indexed)
- `remaining_pages`: Number of pages remaining
- `total_pages`: Total number of pages
- `count_available`: Total number of items available

### Pagination Examples

**Example 1: First Page**
```javascript
// Request
GET /inbox/messages?pagination=true&page=1&limit=10

// Response includes:
{
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "remaining_pages": 4,
    "next": {
      "cursor": 10,
      "query": "?pagination=true&page=2&limit=10"
    }
  }
}
```

**Example 2: Using Cursor**
```javascript
// Request
GET /inbox/messages?pagination=true&cursor=20&limit=10

// Response includes:
{
  "pagination": {
    "current": {
      "cursor": 20,
      "limit": 10
    },
    "next": {
      "cursor": 30,
      "query": "?pagination=true&cursor=30&limit=10"
    }
  }
}
```

**Example 3: Last Page**
```javascript
// Response includes:
{
  "pagination": {
    "current_page": 5,
    "total_pages": 5,
    "remaining_pages": 0,
    "next": null  // No next page
  }
}
```

### Pagination Best Practices

1. **Use query parameters** for GET requests (more cacheable)
2. **Use cursor-based pagination** for large datasets (more efficient)
3. **Use the `next.query` field** from the response to fetch the next page
4. **Default limit is 10** if not specified (configurable in Command Tower)
5. **Handle empty pagination object** - if pagination is not enabled, the response may not include a `pagination` field

---

## Error Handling

### Error Response Format

All errors follow a consistent format:

```json
{
  "status": "400",
  "message": "Error message description",
  "invalid_argument_hash": {
    "field_name": "Field-specific error message"
  }
}
```

### HTTP Status Codes

- **200 OK**: Request successful
- **400 Bad Request**: Invalid parameters or resource not found
- **401 Unauthorized**: Missing or invalid JWT token
- **403 Forbidden**: Valid token but insufficient permissions
- **412 Precondition Failed**: Email verification required

### Common Error Scenarios

**1. Missing JWT Token:**
```json
{
  "status": "401",
  "message": "Bearer token missing"
}
```

**2. Invalid Message ID:**
```json
{
  "status": "400",
  "message": "Message ID not found for user",
  "invalid_argument_hash": {
    "id": "Message ID not found for user"
  }
}
```

**3. Unauthorized Access (Message Blast):**
```json
{
  "status": "403",
  "message": "User is not authorized for this action"
}
```

**4. Missing Required Parameter:**
```json
{
  "status": "400",
  "message": "Parameter [title] is required but not present",
  "invalid_argument_hash": {
    "title": "Parameter [title] is required but not present"
  }
}
```

**5. Email Verification Required:**
```json
{
  "status": "412",
  "message": "Email verification required",
  "meta": {
    "email_validated": false
  }
}
```

### Error Handling Example

```javascript
async function fetchMessages(token) {
  try {
    const response = await fetch('https://api.example.com/inbox/messages', {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      const error = await response.json();

      switch (response.status) {
        case 401:
          // Token expired or invalid - redirect to login
          handleAuthenticationError();
          break;
        case 403:
          // Insufficient permissions
          showError('You do not have permission to access this resource');
          break;
        case 412:
          // Email verification required
          redirectToEmailVerification();
          break;
        default:
          // Other errors
          showError(error.message || 'An error occurred');
      }
      return null;
    }

    return await response.json();
  } catch (error) {
    // Network error
    showError('Network error. Please check your connection.');
    return null;
  }
}
```

---

## CSRF Protection

When using **cookie-based authentication**, CSRF protection is required for unsafe HTTP methods (POST, PATCH, DELETE).

### How CSRF Protection Works

1. **CSRF Token Cookie**: When cookie auth is enabled, Command Tower sets a CSRF token in a cookie (readable by JavaScript, not HttpOnly)
2. **CSRF Token Header**: For unsafe requests, you must read the CSRF token from the cookie and send it in the `X-CSRF-Token` header
3. **Validation**: Command Tower compares the cookie token with the header token using constant-time comparison

### CSRF Token Cookie Name

The CSRF cookie name is configurable in Command Tower. Typically it follows the pattern:
- Default: Based on JWT cookie name + `_csrf` suffix
- Check your Command Tower configuration for the exact cookie name

### Reading CSRF Token

**JavaScript Example:**
```javascript
function getCsrfToken() {
  // Cookie name is configurable - check your Command Tower config
  const cookieName = 'your_app_csrf_token'; // Replace with actual cookie name

  const cookies = document.cookie.split(';');
  for (let cookie of cookies) {
    const [name, value] = cookie.trim().split('=');
    if (name === cookieName) {
      return decodeURIComponent(value);
    }
  }
  return null;
}
```

**Using a Cookie Library:**
```javascript
import Cookies from 'js-cookie';

const csrfToken = Cookies.get('your_app_csrf_token');
```

### Including CSRF Token in Requests

**Example:**
```javascript
const csrfToken = getCsrfToken();

const response = await fetch('https://api.example.com/inbox/messages/ack', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,  // May not be needed if using cookie auth
    'Content-Type': 'application/json',
    'X-CSRF-Token': csrfToken  // Required for cookie-based auth
  },
  credentials: 'include',  // Important: Include cookies in request
  body: JSON.stringify({
    ids: [1, 2, 3]
  })
});
```

### CSRF Error Responses

**Missing CSRF Token:**
```json
{
  "status": "403",
  "message": "csrf_missing"
}
```

**CSRF Token Mismatch:**
```json
{
  "status": "403",
  "message": "csrf_mismatch"
}
```

### When CSRF is Required

- **Required for**: POST, PATCH, DELETE requests when using cookie-based authentication
- **Not required for**: GET, HEAD, OPTIONS requests
- **Not required for**: Header-based authentication (Bearer token in Authorization header)

### CSRF Token Rotation

Command Tower may rotate CSRF tokens:
- On token refresh (if `rotate_on_reset` is enabled)
- When token expires and is refreshed

Your application should handle token rotation by reading the CSRF token fresh for each request, rather than caching it.

---

## Token Management

### JWT Token Lifecycle

1. **Obtain Token**: Login endpoint returns JWT token
2. **Use Token**: Include in `Authorization: Bearer <token>` header
3. **Monitor Expiration**: Check `X-Authorization-Expire` response header
4. **Refresh Token**: Use `X-Authorization-Reset: true` header to request new token

### Token Refresh

Command Tower supports automatic token refresh. Include the `X-Authorization-Reset` header in any authenticated request to get a new token.

**Request:**
```javascript
const response = await fetch('https://api.example.com/inbox/messages', {
  headers: {
    'Authorization': `Bearer ${currentToken}`,
    'X-Authorization-Reset': 'true',  // Request token refresh
    'Content-Type': 'application/json'
  }
});
```

**Response Headers:**
- `X-Authorization-Reset`: Contains the new JWT token
- `X-Authorization-Expire`: Contains the new expiration timestamp

**Example Token Refresh:**
```javascript
async function fetchWithTokenRefresh(token) {
  const response = await fetch('https://api.example.com/inbox/messages', {
    headers: {
      'Authorization': `Bearer ${token}`,
      'X-Authorization-Reset': 'true',
      'Content-Type': 'application/json'
    }
  });

  // Check for new token
  const newToken = response.headers.get('X-Authorization-Reset');
  if (newToken) {
    // Store new token
    storeToken(newToken);

    // Update expiration
    const expiresAt = response.headers.get('X-Authorization-Expire');
    storeTokenExpiration(expiresAt);
  }

  return response;
}
```

### Token Expiration Monitoring

Monitor the `X-Authorization-Expire` header to know when your token will expire:

```javascript
function checkTokenExpiration(response) {
  const expiresAt = response.headers.get('X-Authorization-Expire');
  if (expiresAt) {
    const expirationTime = new Date(expiresAt);
    const now = new Date();
    const timeUntilExpiry = expirationTime - now;

    // Refresh token if it expires in less than 5 minutes
    if (timeUntilExpiry < 5 * 60 * 1000) {
      refreshToken();
    }
  }
}
```

### Cookie-Based Token Management

If using cookie-based authentication:
- Token is automatically included in requests (no need for Authorization header)
- Token is stored in HttpOnly cookie (not accessible to JavaScript)
- CSRF protection is required for unsafe methods
- Token refresh updates the cookie automatically

**Example with Cookies:**
```javascript
// Token is automatically sent via cookie
const response = await fetch('https://api.example.com/inbox/messages', {
  credentials: 'include',  // Include cookies
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': getCsrfToken()  // For POST/PATCH/DELETE
  }
});
```

---

## Complete Integration Example

Here's a complete example of a messaging client:

```javascript
class CommandTowerMessagingClient {
  constructor(baseUrl, token) {
    this.baseUrl = baseUrl;
    this.token = token;
  }

  // Helper to get CSRF token (if using cookie auth)
  getCsrfToken() {
    const cookies = document.cookie.split(';');
    for (let cookie of cookies) {
      const [name, value] = cookie.trim().split('=');
      if (name.includes('csrf')) {
        return decodeURIComponent(value);
      }
    }
    return null;
  }

  // Helper to make authenticated requests
  async request(endpoint, options = {}) {
    const headers = {
      'Authorization': `Bearer ${this.token}`,
      'Content-Type': 'application/json',
      ...options.headers
    };

    // Add CSRF token for unsafe methods if using cookie auth
    if (['POST', 'PATCH', 'DELETE'].includes(options.method)) {
      const csrfToken = this.getCsrfToken();
      if (csrfToken) {
        headers['X-CSRF-Token'] = csrfToken;
      }
    }

    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      ...options,
      headers,
      credentials: 'include'  // Include cookies if using cookie auth
    });

    // Check for token refresh
    const newToken = response.headers.get('X-Authorization-Reset');
    if (newToken) {
      this.token = newToken;
      // Store new token in your app's state management
    }

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || 'Request failed');
    }

    return response.json();
  }

  // Get messages with pagination
  async getMessages(page = 1, limit = 10) {
    return this.request(
      `/inbox/messages?pagination=true&page=${page}&limit=${limit}`
    );
  }

  // Get single message
  async getMessage(id) {
    return this.request(`/inbox/messages/${id}`);
  }

  // Acknowledge messages
  async acknowledgeMessages(ids) {
    return this.request('/inbox/messages/ack', {
      method: 'POST',
      body: JSON.stringify({ ids })
    });
  }

  // Delete messages
  async deleteMessages(ids) {
    return this.request('/inbox/messages/delete', {
      method: 'POST',
      body: JSON.stringify({ ids })
    });
  }

  // Admin: Get message blasts
  async getMessageBlasts(page = 1, limit = 10) {
    return this.request(
      `/inbox/blast?pagination=true&page=${page}&limit=${limit}`
    );
  }

  // Admin: Get single message blast
  async getMessageBlast(id) {
    return this.request(`/inbox/blast/${id}`);
  }

  // Admin: Create message blast
  async createMessageBlast({ title, text, existing_users, new_users }) {
    return this.request('/inbox/blast', {
      method: 'POST',
      body: JSON.stringify({ title, text, existing_users, new_users })
    });
  }

  // Admin: Update message blast
  async updateMessageBlast(id, updates) {
    return this.request(`/inbox/blast/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(updates)
    });
  }

  // Admin: Delete message blast
  async deleteMessageBlast(id) {
    return this.request(`/inbox/blast/${id}`, {
      method: 'DELETE'
    });
  }
}

// Usage example
const client = new CommandTowerMessagingClient(
  'https://api.example.com',
  userJwtToken
);

// Get user's messages
const messages = await client.getMessages(1, 20);
console.log(`Found ${messages.count} messages`);

// View a message (automatically marks as viewed)
const message = await client.getMessage(messages.entities[0].id);
console.log(message.text);

// Acknowledge multiple messages
await client.acknowledgeMessages([1, 2, 3]);

// Admin: Create a message blast
await client.createMessageBlast({
  title: 'System Update',
  text: 'We have updated our system...',
  existing_users: true,
  new_users: false
});
```

---

## Summary

### Key Points

1. **Authentication**: All endpoints require JWT token in `Authorization: Bearer <token>` header
2. **Authorization**: Message blasts require admin role
3. **Messages**: User-scoped, individual notifications
4. **Message Blasts**: Admin-created templates that generate messages for users
5. **Pagination**: Available on list endpoints via query params or request body
6. **CSRF Protection**: Required for POST/PATCH/DELETE when using cookie-based auth
7. **Token Refresh**: Use `X-Authorization-Reset: true` header to refresh tokens
8. **Error Handling**: Consistent error format with status codes and messages

### Endpoint Quick Reference

**Messages (User):**
- `GET /inbox/messages` - List messages (paginated)
- `GET /inbox/messages/:id` - Get single message (auto-marks as viewed)
- `POST /inbox/messages/ack` - Mark messages as viewed
- `POST /inbox/messages/delete` - Delete messages

**Message Blasts (Admin):**
- `GET /inbox/blast` - List blasts (paginated)
- `GET /inbox/blast/:id` - Get single blast
- `POST /inbox/blast` - Create blast
- `PATCH /inbox/blast/:id` - Update blast
- `DELETE /inbox/blast/:id` - Delete blast

For more information about Command Tower authentication and configuration, see the [Authentication Guide](authentication.md) and [Cookie Authentication Guide](cookie_authentication_guide.md).
