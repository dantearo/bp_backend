# Flight Requests API Documentation

## Overview
This API provides comprehensive flight request management functionality for the Presidential Flight Booking Platform. All endpoints are secured and support role-based access control.

## Base URL
```
/api/v1
```

## Authentication
All endpoints require authentication. In test environment, authentication is bypassed for testing purposes.

## Flight Requests

### Core CRUD Operations

#### List Flight Requests
```http
GET /api/v1/flight_requests
```

**Query Parameters:**
- `page` (integer): Page number for pagination
- `per_page` (integer): Items per page (default: 10)
- `status` (string): Filter by status (sent, received, under_review, under_process, done, unable)
- `vip_profile_id` (integer): Filter by VIP profile
- `from_date` (date): Filter requests from date
- `to_date` (date): Filter requests to date

**Response:**
```json
{
  "flight_requests": [
    {
      "id": 1,
      "request_number": "001/2025",
      "flight_date": "2025-01-15",
      "departure_airport": "DXB",
      "arrival_airport": "JFK",
      "departure_time": "08:00",
      "arrival_time": null,
      "passengers": 3,
      "status": "sent",
      "vip_profile": "EAGLE_ONE",
      "created_at": "2025-01-10T10:00:00Z",
      "overdue_alerts": []
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 10,
    "total_count": 5
  }
}
```

#### Get Single Flight Request
```http
GET /api/v1/flight_requests/:id
```

**Response:**
```json
{
  "id": 1,
  "request_number": "001/2025",
  "flight_date": "2025-01-15",
  "departure_airport": "DXB",
  "arrival_airport": "JFK",
  "departure_time": "08:00",
  "arrival_time": null,
  "passengers": 3,
  "status": "sent",
  "reason_unable_to_process": null,
  "vip_profile": {
    "id": 1,
    "codename": "EAGLE_ONE"
  },
  "source_of_request_user": {
    "id": 1,
    "name": "John Doe"
  },
  "legs": [],
  "created_at": "2025-01-10T10:00:00Z",
  "updated_at": "2025-01-10T10:00:00Z",
  "overdue_alerts": []
}
```

#### Create Flight Request
```http
POST /api/v1/flight_requests
```

**Request Body:**
```json
{
  "vip_profile_id": 1,
  "flight_request": {
    "flight_date": "2025-01-15",
    "departure_airport_code": "DXB",
    "arrival_airport_code": "JFK",
    "departure_time": "08:00",
    "number_of_passengers": 3
  }
}
```

**Validation Rules:**
- Either `departure_time` OR `arrival_time` must be provided (not both)
- `flight_date` cannot be in the past
- All fields are required except `arrival_time` when `departure_time` is provided
- Airport codes must be valid IATA codes
- Number of passengers must be between 1 and 50

**Response:**
```json
{
  "message": "Flight request created successfully",
  "flight_request": { ... },
  "confirmation_required": true
}
```

#### Update Flight Request
```http
PUT /api/v1/flight_requests/:id
```

**Request Body:**
```json
{
  "flight_request": {
    "number_of_passengers": 5
  }
}
```

#### Delete Flight Request (Soft Delete)
```http
DELETE /api/v1/flight_requests/:id
```

**Note:** Only admin users can delete requests. This performs a soft delete.

### Advanced Features

#### Update Flight Request Status
```http
PUT /api/v1/flight_requests/:id/status
```

**Request Body:**
```json
{
  "status": "received"
}
```

**Valid Status Transitions:**
- `sent` → `received`, `unable`
- `received` → `under_review`, `unable`
- `under_review` → `under_process`, `unable`
- `under_process` → `done`, `unable`

#### Upload Passenger List
```http
POST /api/v1/flight_requests/:id/passenger_list
```

**Requirements:**
- Flight request status must be "done"
- File must be PDF format
- Only available to source users for their own requests

#### Upload Flight Brief
```http
POST /api/v1/flight_requests/:id/flight_brief
```

**Requirements:**
- Only operations staff and admin users can upload
- File must be PDF format

## Multi-leg Flight Support

#### Add Flight Leg
```http
POST /api/v1/flight_requests/:flight_request_id/legs
```

**Request Body:**
```json
{
  "leg": {
    "departure_airport_code": "JFK",
    "arrival_airport_code": "LAX",
    "departure_time": "14:00"
  }
}
```

#### Update Flight Leg
```http
PUT /api/v1/flight_requests/:flight_request_id/legs/:id
```

#### Delete Flight Leg
```http
DELETE /api/v1/flight_requests/:flight_request_id/legs/:id
```

## Role-Based Access Control

### Source of Request Users
- Can create flight requests for assigned VIP profiles
- Can view only their own requests
- Can upload passenger lists for completed requests
- Cannot update request status

### VIP Users
- Can view requests made on their behalf
- Cannot create or modify requests directly

### Operations Staff
- Can view all flight requests
- Can update request status
- Can upload flight briefs
- Cannot delete requests

### Operations Admin
- All operations staff permissions
- Can delete flight requests (soft delete)
- Can manage other users

### Management
- Read-only access to all requests for oversight

### Super Admin
- Full system access
- Can perform all operations

## Error Responses

### Validation Errors
```json
{
  "errors": [
    "Flight date cannot be in the past",
    "Either departure time or arrival time must be specified"
  ]
}
```

### Authorization Errors
```json
{
  "error": "Unauthorized"
}
```

### Not Found Errors
```json
{
  "error": "Record not found"
}
```

## Business Rules

1. **Request Numbering**: Sequential format `001/YYYY`
2. **Time Logic**: Only departure OR arrival time allowed, not both
3. **Conflict Detection**: Prevents overlapping requests for same VIP on same date
4. **Weekend Restrictions**: Weekend flights require special authorization
5. **Security Clearance**: Certain destinations require higher clearance levels
6. **Audit Trail**: All actions are logged for compliance
7. **Soft Deletes**: No data is permanently removed

## Status Workflow

```
sent → received → under_review → under_process → done
  ↓       ↓           ↓              ↓
unable  unable      unable        unable
```

## Alert System

The system generates alerts for requests approaching flight time:
- 72 hours before flight
- 48 hours before flight  
- 24 hours before flight
- 12 hours before flight
- 6 hours before flight
