# GitHub Secrets Configuration

## Required Secrets for CI/CD Pipeline

To enable the database deployment workflow, configure the following secrets in your GitHub repository:

**Go to: Repository → Settings → Secrets and variables → Actions → New repository secret**

### Database Connection Secrets

| Secret Name | Value |
|-------------|-------|
| `DB_SERVER` | `sql-insurance-hdi-andre789.database.windows.net` |
| `DB_NAME` | `insurance_hdi` |
| `DB_USER` | `sqladmin` |
| `DB_PASS` | `=neISb4G0:NYzzw!H0B!` |

### Setup Instructions

1. **Navigate to GitHub Repository**
   ```
   https://github.com/<your-username>/<repository-name>/settings/secrets/actions
   ```

2. **Add Each Secret:**
   - Click "New repository secret"
   - Enter the Secret Name (exactly as shown above)
   - Enter the corresponding Value
   - Click "Add secret"

3. **Verify Configuration:**
   - All 4 secrets should appear in the "Repository secrets" list
   - Secret values will be masked with asterisks

### Security Notes

- These secrets are encrypted and only accessible to GitHub Actions workflows
- Never commit database passwords to source code
- Consider rotating passwords periodically
- Use Azure Key Vault for production environments

### Testing the Setup

After adding secrets, trigger the workflow by:
- Pushing changes to SQL files in `infra/sqlserver/`
- Or manually running the workflow from Actions tab

The workflow will automatically apply database migrations in the correct order.