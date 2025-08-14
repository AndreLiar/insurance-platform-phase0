# Azure AD B2C Setup Guide - Free Student Plan

## Overview
Azure AD B2C provides free authentication for up to 50,000 monthly active users - perfect for Azure Student plans.

## Step 1: Create Azure AD B2C Tenant

1. **Login to Azure Portal**
   ```
   https://portal.azure.com
   ```

2. **Create B2C Tenant**
   - Click "Create a resource" → Search "Azure Active Directory B2C"
   - Select "Create a new Azure AD B2C Tenant"
   - Choose tenant name: `insurance-hdi-b2c` (or your preference)
   - Domain: `insurance-hdi-b2c.onmicrosoft.com`
   - Country: Select your country
   - Click "Create"

3. **Switch to B2C Tenant**
   - After creation, click "Switch to your new tenant"
   - Or use tenant switcher in top-right corner

## Step 2: Register Application

1. **Navigate to App Registrations**
   - In B2C tenant, go to Azure AD B2C → App registrations
   - Click "New registration"

2. **Configure Application**
   - Name: `Insurance Platform API`
   - Account types: "Accounts in this organizational directory only"
   - Redirect URI: `https://localhost:5001/signin-oidc` (for dev)
   - Click "Register"

3. **Note Application Details**
   - Copy **Application (client) ID**
   - Copy **Directory (tenant) ID**

4. **Create Client Secret**
   - Go to "Certificates & secrets"
   - Click "New client secret"
   - Description: "API Secret"
   - Expires: 24 months
   - Click "Add"
   - **Copy the secret value immediately** (won't show again)

## Step 3: Create User Flows

1. **Sign-up and Sign-in Flow**
   - Go to Azure AD B2C → User flows
   - Click "New user flow"
   - Select "Sign up and sign in" → "Recommended"
   - Name: `SignUpSignIn`
   - Identity providers: Select "Email signup"
   - User attributes: Select required fields:
     - Email Address (collect + return)
     - Display Name (collect + return)
     - Given Name (collect + return)
     - Surname (collect + return)
   - Click "Create"

2. **Additional Flows (Optional)**
   - Profile editing: `ProfileEdit`
   - Password reset: `PasswordReset`

## Step 4: Configure API Permissions

1. **API Permissions**
   - In app registration, go to "API permissions"
   - Add Microsoft Graph permissions:
     - `User.Read` (Delegated)
     - `offline_access` (Delegated)

2. **Expose API (Optional for future phases)**
   - Go to "Expose an API"
   - Set Application ID URI: `https://insurance-hdi-b2c.onmicrosoft.com/api`

## Step 5: Update Configuration

Update your `appsettings.json` with actual values:

```json
{
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

## Step 6: Test Authentication

1. **Start your API**
   ```bash
   cd api
   dotnet run
   ```

2. **Test Endpoints**
   - Health: `https://localhost:5001/healthz`
   - Protected: `https://localhost:5001/api/security/users`
   - Metrics: `https://localhost:5001/metrics`

3. **Authentication Flow**
   - Navigate to protected endpoint
   - Should redirect to B2C sign-in page
   - Create account or sign in
   - Should return to application with token

## Step 7: Production Configuration

For production, update:
- Redirect URIs to production domains
- Add CORS origins
- Configure custom domains (optional)
- Set up custom branding

## Pricing - Student Plan Benefits

**Azure AD B2C Free Tier:**
- 50,000 Monthly Active Users (MAU)
- Unlimited authentications
- Basic identity providers
- User flows and custom policies
- Perfect for development and small applications

**Costs only apply after 50,000 MAU:**
- $0.00325 per MAU beyond free tier
- Premium features require P1/P2 licenses

## Security Best Practices

1. **Store secrets securely**
   - Use Azure Key Vault for production
   - Environment variables for development
   - Never commit secrets to source control

2. **Configure token lifetimes**
   - Access tokens: 1 hour
   - Refresh tokens: 24 hours
   - ID tokens: 1 hour

3. **Enable logging**
   - Application Insights integration
   - Audit logs in Azure AD B2C

## Troubleshooting

**Common Issues:**
- Redirect URI mismatch → Check app registration
- Invalid client credentials → Verify client secret
- Policy not found → Check user flow name
- CORS errors → Configure allowed origins

**Useful URLs:**
- B2C tenant: `https://insurance-hdi-b2c.b2clogin.com`
- User flow test: Available in Azure Portal user flow page
- Token validation: `https://jwt.ms` for debugging tokens