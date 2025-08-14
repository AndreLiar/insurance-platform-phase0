# JWT Authentication Guide - Simple & Secure

## Overview

Since Azure AD B2C requires admin permissions, we've implemented a simple JWT-based authentication system that works immediately without any Azure AD setup.

## 🚀 Quick Start

### 1. Start the API
```bash
cd api
dotnet run
```

### 2. Register a New User
```bash
curl -X POST https://localhost:5001/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@insurance.com",
    "password": "SecurePassword123!",
    "firstName": "Admin",
    "lastName": "User"
  }'
```

**Response:**
```json
{
  "message": "User created successfully",
  "userId": "12345678-1234-1234-1234-123456789012"
}
```

### 3. Login to Get JWT Token
```bash
curl -X POST https://localhost:5001/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@insurance.com", 
    "password": "SecurePassword123!"
  }'
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "userId": "12345678-1234-1234-1234-123456789012",
    "tenantId": "00000000-0000-0000-0000-000000000001",
    "email": "admin@insurance.com",
    "firstName": "Admin",
    "lastName": "User"
  },
  "expiresAt": "2024-01-01T13:00:00Z"
}
```

### 4. Use Token for Protected Endpoints
```bash
# Copy the token from login response
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Access protected dashboard
curl -H "Authorization: Bearer $TOKEN" https://localhost:5001/dashboard

# Access protected API
curl -H "Authorization: Bearer $TOKEN" https://localhost:5001/api/security/users
```

## 📋 API Endpoints

### Public Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/healthz` | GET | Health check |
| `/ready` | GET | Readiness check |
| `/metrics` | GET | Prometheus metrics |
| `/auth/register` | POST | Create new user account |
| `/auth/login` | POST | Login and get JWT token |

### Protected Endpoints (Requires JWT Token)
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/dashboard` | GET | User dashboard |
| `/api/security/users` | GET | List users (tenant-filtered) |

## 🔐 Security Features

### Password Security
- **BCrypt Hashing**: Industry-standard password hashing
- **Salt + Hash**: Each password gets unique salt
- **No Plain Text**: Passwords never stored in plain text

### JWT Token Security
- **HMAC-SHA256**: Cryptographic signing
- **1 Hour Expiration**: Tokens auto-expire
- **Claims-based**: User info embedded in token
- **Tenant Isolation**: Each token tied to specific tenant

### Row Level Security (RLS)
- **Automatic**: JWT claims set session context
- **Tenant Filtering**: Users only see their tenant data  
- **User Tracking**: All operations tracked by user ID

## 🧪 Testing the Complete Flow

### 1. Register Multiple Users
```bash
# User 1 (Default tenant)
curl -X POST https://localhost:5001/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@tenant1.com", "password": "Password123!", "firstName": "Alice", "lastName": "Admin"}'

# User 2 (Different tenant - use header)
curl -X POST https://localhost:5001/auth/register \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Id: 11111111-1111-1111-1111-111111111111" \
  -d '{"email": "bob@tenant2.com", "password": "Password123!", "firstName": "Bob", "lastName": "Manager"}'
```

### 2. Login as Each User
```bash
# Login as Alice
curl -X POST https://localhost:5001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@tenant1.com", "password": "Password123!"}'

# Save Alice's token
ALICE_TOKEN="[copy token from response]"

# Login as Bob  
curl -X POST https://localhost:5001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "bob@tenant2.com", "password": "Password123!"}'

# Save Bob's token
BOB_TOKEN="[copy token from response]"
```

### 3. Test Tenant Isolation
```bash
# Alice sees only her tenant's users
curl -H "Authorization: Bearer $ALICE_TOKEN" https://localhost:5001/api/security/users

# Bob sees only his tenant's users  
curl -H "Authorization: Bearer $BOB_TOKEN" https://localhost:5001/api/security/users
```

## 🔧 Configuration

### JWT Settings (appsettings.json)
```json
{
  "JwtSettings": {
    "SecretKey": "InsurancePlatform-SuperSecretKey-2024-ChangeInProduction-32Characters",
    "Issuer": "InsurancePlatform", 
    "Audience": "InsurancePlatformAPI",
    "ExpirationMinutes": 60
  }
}
```

**⚠️ Security Note**: Change `SecretKey` in production!

### Environment Variables
```bash
# Optional: Override via environment variables
export JWT_SECRET="your-production-secret-key-here"
export JWT_EXPIRATION_MINUTES=30
```

## 🎯 JWT Token Claims

Each JWT token contains these claims:
```json
{
  "user_id": "12345678-1234-1234-1234-123456789012",
  "tenant_id": "00000000-0000-0000-0000-000000000001", 
  "email": "user@example.com",
  "name": "First Last",
  "first_name": "First",
  "last_name": "Last",
  "iss": "InsurancePlatform",
  "aud": "InsurancePlatformAPI",
  "exp": 1704110400
}
```

## 🛠 Database Integration

### User Storage
Users are stored in `SECURITY.USER_ACCOUNT` with:
- `auth_provider = 'LOCAL'` (vs 'AZURE_B2C')
- `password_hash` contains BCrypt hash
- `external_user_id` is NULL for local users

### RLS Integration  
The JWT claims automatically set:
```sql
EXEC sys.sp_set_session_context @key=N'tenant_id', @value='[from JWT]';
EXEC sys.sp_set_session_context @key=N'user_id', @value='[from JWT]';
```

## 🚦 Migration from Azure AD B2C

When you get Azure AD admin access later, you can:
1. Keep existing JWT authentication
2. Add Azure AD B2C as additional provider
3. Support both `auth_provider = 'LOCAL'` and `'AZURE_B2C'`
4. Migrate users gradually

## 🔍 Troubleshooting

### Common Issues

**"Invalid token" errors:**
```bash
# Check token expiration
# Tokens expire after 1 hour - login again
```

**"Unauthorized" responses:**
```bash
# Verify Authorization header format
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
# Note: "Bearer " prefix is required
```

**"User already exists" on registration:**
```bash
# Use different email or login with existing credentials
```

### Debug Commands
```bash
# Test API is running
curl https://localhost:5001/healthz

# Validate JWT token structure (paste token at jwt.io)
echo $TOKEN | base64 -d

# Check database connection
curl -X POST https://localhost:5001/auth/login -H "Content-Type: application/json" -d '{"email":"test","password":"test"}'
# Should return 401 (Unauthorized) not 500 (Server Error)
```

## 🎉 Success Criteria

Your authentication is working when:
- ✅ Registration creates users in database
- ✅ Login returns valid JWT tokens  
- ✅ Protected endpoints require Bearer token
- ✅ RLS enforces tenant isolation
- ✅ Different users see different data
- ✅ Tokens expire after 1 hour

**You now have enterprise-grade authentication without Azure AD dependencies!** 🚀