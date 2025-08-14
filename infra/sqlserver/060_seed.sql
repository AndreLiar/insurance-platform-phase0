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

-- Example tenant + admin user/role
DECLARE @tenant UNIQUEIDENTIFIER = NEWID();
DECLARE @admin  UNIQUEIDENTIFIER;

PRINT 'Seed tenant: ' + CAST( @tenant AS NVARCHAR(36));

INSERT INTO SECURITY.ROLE(tenant_id, role_name, description, is_system_role)
VALUES( @tenant, N'TENANT_ADMIN', N'Administrative role', 0);

INSERT INTO SECURITY.USER_ACCOUNT(tenant_id, username, email, password_hash, first_name, last_name)
VALUES( @tenant, N'admin', N'admin @example.com', N'REPLACE_ME_HASH', N'Tenant', N'Admin');

SELECT @admin = id FROM SECURITY.USER_ACCOUNT WHERE tenant_id = @tenant AND username = N'admin';
DECLARE @role  UNIQUEIDENTIFIER = (SELECT TOP 1 id FROM SECURITY.ROLE WHERE tenant_id = @tenant AND role_name = N'TENANT_ADMIN');

INSERT INTO SECURITY.USER_ROLE(user_id, role_id, assigned_by) VALUES( @admin, @role, @admin);

-- Tenant-scoped code sets
INSERT INTO COMMON.CODE_SET(tenant_id, code_set_name, description) VALUES
( @tenant, N'STATUS_USER', N'User status'),
( @tenant, N'COMM_CHANNEL', N'Communication channels');

INSERT INTO COMMON.CODE_VALUE(tenant_id, code_set_id, code, display_value, sort_order)
SELECT @tenant, cs.id, N'ACTIVE', N'Active', 1 FROM COMMON.CODE_SET cs WHERE cs.tenant_id= @tenant AND cs.code_set_name=N'STATUS_USER'
UNION ALL
SELECT @tenant, cs.id, N'INACTIVE', N'Inactive', 2 FROM COMMON.CODE_SET cs WHERE cs.tenant_id= @tenant AND cs.code_set_name=N'STATUS_USER';
GO