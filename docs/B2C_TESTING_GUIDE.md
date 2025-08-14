# Azure AD B2C Testing Guide

## Quick Test Steps

### 1. Complete Azure B2C Setup
Follow `AZURE_B2C_EMAIL_PASSWORD_SETUP.md` to:
- ✅ Create B2C tenant
- ✅ Register application 
- ✅ Create user flow
- ✅ Update `appsettings.json` with your values

### 2. Update Database Schema
Run the new B2C user mapping migration:

```bash
# Add to your GitHub workflow or run manually
sqlcmd -S sql-insurance-hdi-andre789.database.windows.net \
       -d insurance_hdi \
       -U sqladmin \
       -P "=neISb4G0:NYzzw!H0B!" \
       -i infra/sqlserver/065_b2c_user_mapping.sql
```

### 3. Start Your API

```bash
cd api
dotnet run
```

Your API will run on: `https://localhost:5001`

### 4. Test Authentication Flow

#### Step 1: Try Protected Endpoint (Unauthenticated)
```bash
curl https://localhost:5001/api/security/users
# Should redirect to B2C login
```

#### Step 2: Login via Browser
1. Open browser: `https://localhost:5001/login`
2. Should redirect to B2C: `https://insurance-hdi-b2c.b2clogin.com/...`
3. Create account with email/password
4. Should redirect back to: `https://localhost:5001/dashboard`

#### Step 3: View User Dashboard
After login, you should see:
```json
{
  "message": "Welcome to Insurance Platform!",
  "user": {
    "id": "b2c-object-id-here",
    "email": "your-email@example.com", 
    "name": "Your Name",
    "givenName": "Your",
    "surname": "Name"
  },
  "allClaims": [
    // All B2C claims will be listed here
  ]
}
```

#### Step 4: Test Protected API
```bash
# This should now work (with browser session)
curl -b cookies.txt https://localhost:5001/api/security/users
```

### 5. Test Database Integration

Your B2C user should be automatically created in database:

```sql
-- Check if B2C user was created
SELECT * FROM SECURITY.vw_B2CUsers;

-- Should show something like:
-- id: [guid]
-- tenant_id: 00000000-0000-0000-0000-000000000001  
-- email: your-email@example.com
-- b2c_object_id: [B2C Object ID]
-- first_name: Your
-- last_name: Name
-- roles: NULL (no roles assigned yet)
```

### 6. Test RLS (Row Level Security)

The API should automatically set session context for RLS:

```sql
-- Simulate what the API does
EXEC sys.sp_set_session_context @key=N'tenant_id', @value='00000000-0000-0000-0000-000000000001';
EXEC sys.sp_set_session_context @key=N'user_id', @value='[B2C-Object-ID]';

-- Query should only return users for current tenant
SELECT * FROM SECURITY.USER_ACCOUNT;
```

## Expected Test Results

### ✅ Successful Flow:
1. **Login Redirect**: Browser redirects to B2C login page
2. **Account Creation**: Can create account with email/password
3. **Authentication**: Redirects back with valid token
4. **Dashboard Access**: Shows user info from B2C claims
5. **API Access**: Protected endpoints work with session
6. **Database Integration**: User created in `USER_ACCOUNT` table
7. **RLS Enforcement**: Only sees data for their tenant

### ❌ Common Issues:

**"AADSTS50011: Redirect URI mismatch"**
- Check app registration redirect URI: `https://localhost:5001/signin-oidc`

**"Unable to get metadata"**  
- Verify Authority URL in `appsettings.json`
- Check B2C tenant name and policy name

**"Database connection failed"**
- Verify SQL connection string
- Check firewall rules for Azure SQL

**"Claims not found"**
- Verify user flow returns required claims
- Check B2C user flow configuration

## API Endpoints Reference

| Endpoint | Method | Auth Required | Purpose |
|----------|--------|---------------|---------|
| `/healthz` | GET | No | Health check |
| `/ready` | GET | No | Readiness check |
| `/metrics` | GET | No | Prometheus metrics |
| `/login` | GET | No | Initiate B2C login |
| `/logout` | POST | Yes | Sign out |
| `/dashboard` | GET | Yes | User info display |
| `/api/security/users` | GET | Yes | Protected API test |

## User Flow Diagram

```
1. User → /login
2. Redirect → B2C Login Page  
3. User → Enter email/password
4. B2C → Validate credentials
5. Redirect → /dashboard (with token)
6. API → Extract claims from token
7. Database → Create/update user record
8. Response → User dashboard with info
```

## Next Steps After Successful Testing

1. **Add Role Assignment**: Assign default "USER" role to new B2C users
2. **Tenant Mapping**: Map B2C users to insurance company tenants
3. **Claims Transformation**: Add custom claims for business logic
4. **UI Integration**: Build React/Angular frontend
5. **Production Config**: Configure production domains and secrets

## Troubleshooting Commands

```bash
# Check API logs
dotnet run --verbosity detailed

# Test B2C metadata endpoint
curl https://insurance-hdi-b2c.b2clogin.com/insurance-hdi-b2c.onmicrosoft.com/B2C_1_SignUpSignIn/v2.0/.well-known/openid_configuration

# Validate JWT token
# Copy token from browser developer tools and paste at https://jwt.ms

# Test database connection
sqlcmd -S sql-insurance-hdi-andre789.database.windows.net -d insurance_hdi -U sqladmin -P "=neISb4G0:NYzzw!H0B!" -Q "SELECT @@VERSION"
```