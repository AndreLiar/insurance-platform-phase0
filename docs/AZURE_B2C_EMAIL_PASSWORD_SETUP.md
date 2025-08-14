# Azure AD B2C Setup - Email & Password Only

## Step-by-Step Setup (15 minutes)

### 1. Create B2C Tenant

1. **Go to Azure Portal**: https://portal.azure.com
2. **Create Resource** → Search "Azure Active Directory B2C"
3. **Create new tenant**:
   - Tenant name: `insurance-hdi-b2c`
   - Domain: `insurance-hdi-b2c.onmicrosoft.com`
   - Click **Create**

4. **Switch to new tenant**:
   - Click notification when ready
   - Or use tenant switcher (top right)

### 2. Register Your Application

1. **Go to App registrations** (in B2C tenant)
2. **New registration**:
   - Name: `Insurance Platform`
   - Account types: **Accounts in this organizational directory only**
   - Redirect URI: `Web` → `https://localhost:5001/signin-oidc`
   - Click **Register**

3. **Copy these values** (you'll need them):
   ```
   Application (client) ID: [COPY THIS]
   Directory (tenant) ID: [COPY THIS]
   ```

4. **Create client secret**:
   - Go to **Certificates & secrets**
   - **New client secret**
   - Description: `Main Secret`
   - Expires: **24 months**
   - Click **Add**
   - **COPY THE VALUE NOW** (it disappears!)

### 3. Create Sign-up/Sign-in User Flow

1. **Go to User flows** (in B2C menu)
2. **New user flow**
3. **Sign up and sign in** → **Recommended**
4. **Configuration**:
   - Name: `SignUpSignIn` (exactly this)
   - Identity providers: ✅ **Email signup**
   - User attributes (what to collect):
     - ✅ Email Address
     - ✅ Display Name  
     - ✅ Given Name
     - ✅ Surname
   - Application claims (what to return):
     - ✅ Email Addresses
     - ✅ Display Name
     - ✅ Given Name
     - ✅ Surname
     - ✅ User's Object ID
5. **Create**

### 4. Test Your User Flow

1. **Go to your user flow** → `B2C_1_SignUpSignIn`
2. **Run user flow**
3. **Test URL**: Copy this for later testing
4. Try creating a test account

### 5. Update Your Configuration

Replace your `appsettings.json` with actual values:

```json
{
  "ConnectionStrings": {
    "Sql": "Server=tcp:sql-insurance-hdi-andre789.database.windows.net,1433;Database=insurance_hdi;User ID=sqladmin;Password==neISb4G0:NYzzw!H0B!;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  },
  "AzureAdB2C": {
    "Instance": "https://insurance-hdi-b2c.b2clogin.com",
    "TenantId": "[YOUR_TENANT_ID]",
    "ClientId": "[YOUR_CLIENT_ID]", 
    "ClientSecret": "[YOUR_CLIENT_SECRET]",
    "Domain": "insurance-hdi-b2c.onmicrosoft.com",
    "SignUpSignInPolicyId": "B2C_1_SignUpSignIn",
    "Authority": "https://insurance-hdi-b2c.b2clogin.com/insurance-hdi-b2c.onmicrosoft.com/B2C_1_SignUpSignIn/v2.0/"
  }
}
```

### 6. Add CORS Configuration

In Azure Portal, go to your app registration:
1. **Authentication**
2. **Add platform** → **Web**
3. **Redirect URIs**:
   - `https://localhost:5001/signin-oidc`
   - `https://localhost:7001/signin-oidc` (HTTPS)
4. **Implicit grant**: ✅ ID tokens
5. **Save**

## Your Authentication Flow

```
1. User clicks "Login" in your app
   ↓
2. Redirects to: https://insurance-hdi-b2c.b2clogin.com/.../B2C_1_SignUpSignIn
   ↓  
3. User enters email/password (or creates account)
   ↓
4. B2C redirects back to: https://localhost:5001/signin-oidc
   ↓
5. Your API gets user info from token:
   - Email
   - Name  
   - User ID (maps to your database)
```

## Quick Test

1. **Start your API**:
   ```bash
   cd api
   dotnet run
   ```

2. **Try protected endpoint**:
   ```
   https://localhost:5001/api/security/users
   ```

3. **Expected behavior**:
   - Redirects to B2C login
   - Create account with email/password
   - Returns to your API
   - Shows user data

## User Database Integration

Your users table will map B2C users like this:

```sql
-- B2C user gets mapped to your tenant system
INSERT INTO SECURITY.USER_ACCOUNT(
    tenant_id,           -- Your insurance company ID
    username,            -- B2C user email  
    email,               -- B2C user email
    external_user_id,    -- B2C Object ID
    first_name,          -- From B2C claims
    last_name,           -- From B2C claims
    password_hash        -- NULL (B2C handles passwords)
) VALUES (
    @tenant_id,
    'user@example.com',
    'user@example.com', 
    'b2c-object-id-12345',
    'John',
    'Doe',
    NULL
);
```

## What This Gives You

✅ **Professional login pages** (hosted by Microsoft)  
✅ **Secure password handling** (Microsoft handles)  
✅ **Email verification** (automatic)  
✅ **Password reset** (automatic)  
✅ **Account lockout protection**  
✅ **Enterprise security**  
✅ **FREE for 50,000 users/month**  

## Next Steps

1. Complete the Azure setup above
2. Test with your actual tenant ID/client ID  
3. I'll help integrate with your database
4. Add tenant mapping for insurance companies

**Ready to start? Let me know when you have the B2C tenant created!** 🚀