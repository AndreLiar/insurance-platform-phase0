-- Global catalogs (no tenant)
INSERT INTO COMMON.COUNTRY (iso2_code, iso3_code, country_name) VALUES
  (N'US', N'USA', N'United States'),
  (N'FR', N'FRA', N'France');

INSERT INTO COMMON.CURRENCY (currency_code, currency_name, symbol, decimal_places) VALUES
  (N'USD', N'US Dollar', N'$', 2),
  (N'EUR', N'Euro', N'€', 2);

INSERT INTO COMMON.LANGUAGE (language_code, language_name, native_name) VALUES
  (N'en', N'English', N'English'),
  (N'fr', N'French',  N'Français');

-- Default tenant for Phase 0 testing
DECLARE @tenant UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000001';
DECLARE @admin  UNIQUEIDENTIFIER;
DECLARE @tenantAdminRole UNIQUEIDENTIFIER;
DECLARE @powerUserRole UNIQUEIDENTIFIER;
DECLARE @viewerRole UNIQUEIDENTIFIER;

PRINT 'Seeding Phase 0 tenant: ' + CAST( @tenant AS NVARCHAR(36));

-- Create required roles (idempotent)
IF NOT EXISTS (SELECT 1 FROM SECURITY.ROLE WHERE tenant_id = @tenant AND role_name = N'TENANT_ADMIN')
    INSERT INTO SECURITY.ROLE(tenant_id, role_name, description, is_system_role)
    VALUES( @tenant, N'TENANT_ADMIN', N'Full administrative privileges', 1);

IF NOT EXISTS (SELECT 1 FROM SECURITY.ROLE WHERE tenant_id = @tenant AND role_name = N'POWER_USER')
    INSERT INTO SECURITY.ROLE(tenant_id, role_name, description, is_system_role)
    VALUES( @tenant, N'POWER_USER', N'Advanced user with most privileges', 1);

IF NOT EXISTS (SELECT 1 FROM SECURITY.ROLE WHERE tenant_id = @tenant AND role_name = N'VIEWER')
    INSERT INTO SECURITY.ROLE(tenant_id, role_name, description, is_system_role)
    VALUES( @tenant, N'VIEWER', N'Read-only access to data', 1);

-- Get role IDs
SELECT @tenantAdminRole = id FROM SECURITY.ROLE WHERE tenant_id = @tenant AND role_name = N'TENANT_ADMIN';
SELECT @powerUserRole = id FROM SECURITY.ROLE WHERE tenant_id = @tenant AND role_name = N'POWER_USER';
SELECT @viewerRole = id FROM SECURITY.ROLE WHERE tenant_id = @tenant AND role_name = N'VIEWER';

-- Create permissions (global, not tenant-specific)
IF NOT EXISTS (SELECT 1 FROM SECURITY.PERMISSION WHERE permission_name = N'users.create')
    INSERT INTO SECURITY.PERMISSION(permission_name, description, resource, action) VALUES
    (N'users.create', N'Create new users', N'users', N'create'),
    (N'users.read', N'Read user data', N'users', N'read'),
    (N'users.update', N'Update user data', N'users', N'update'),
    (N'users.delete', N'Delete users', N'users', N'delete'),
    (N'roles.create', N'Create new roles', N'roles', N'create'),
    (N'roles.read', N'Read role data', N'roles', N'read'),
    (N'roles.update', N'Update roles', N'roles', N'update'),
    (N'roles.delete', N'Delete roles', N'roles', N'delete'),
    (N'codesets.create', N'Create code sets', N'codesets', N'create'),
    (N'codesets.read', N'Read code sets', N'codesets', N'read'),
    (N'codesets.update', N'Update code sets', N'codesets', N'update'),
    (N'codesets.delete', N'Delete code sets', N'codesets', N'delete');

-- Assign permissions to roles
-- TENANT_ADMIN gets all permissions
INSERT INTO SECURITY.ROLE_PERMISSION(role_id, permission_id)
SELECT @tenantAdminRole, id FROM SECURITY.PERMISSION 
WHERE NOT EXISTS (SELECT 1 FROM SECURITY.ROLE_PERMISSION WHERE role_id = @tenantAdminRole AND permission_id = SECURITY.PERMISSION.id);

-- POWER_USER gets most permissions except delete
INSERT INTO SECURITY.ROLE_PERMISSION(role_id, permission_id)
SELECT @powerUserRole, id FROM SECURITY.PERMISSION 
WHERE action IN ('create', 'read', 'update')
  AND NOT EXISTS (SELECT 1 FROM SECURITY.ROLE_PERMISSION WHERE role_id = @powerUserRole AND permission_id = SECURITY.PERMISSION.id);

-- VIEWER gets only read permissions
INSERT INTO SECURITY.ROLE_PERMISSION(role_id, permission_id)
SELECT @viewerRole, id FROM SECURITY.PERMISSION 
WHERE action = 'read'
  AND NOT EXISTS (SELECT 1 FROM SECURITY.ROLE_PERMISSION WHERE role_id = @viewerRole AND permission_id = SECURITY.PERMISSION.id);

-- Tenant-scoped code sets
INSERT INTO COMMON.CODE_SET(tenant_id, code_set_name, description) VALUES
( @tenant, N'STATUS_USER', N'User status'),
( @tenant, N'COMM_CHANNEL', N'Communication channels');

INSERT INTO COMMON.CODE_VALUE(tenant_id, code_set_id, code, display_value, sort_order)
SELECT @tenant, cs.id, N'ACTIVE', N'Active', 1 FROM COMMON.CODE_SET cs WHERE cs.tenant_id= @tenant AND cs.code_set_name=N'STATUS_USER'
UNION ALL
SELECT @tenant, cs.id, N'INACTIVE', N'Inactive', 2 FROM COMMON.CODE_SET cs WHERE cs.tenant_id= @tenant AND cs.code_set_name=N'STATUS_USER';
GO