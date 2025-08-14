-- Tenant A session
DECLARE @tenantA UNIQUEIDENTIFIER = NEWID();
DECLARE @tenantB UNIQUEIDENTIFIER = NEWID();

EXEC sys.sp_set_session_context @key=N'tenant_id', @value=@tenantA;
EXEC sys.sp_set_session_context @key=N'user_id',   @value=NEWID();

INSERT INTO SECURITY.USER_ACCOUNT(tenant_id, username, email, password_hash) 
VALUES( @tenantA, 'alice', 'alice @a.com', 'x');

-- Tenant B session
EXEC sys.sp_set_session_context @key=N'tenant_id', @value=@tenantB;
EXEC sys.sp_set_session_context @key=N'user_id',   @value=NEWID();

INSERT INTO SECURITY.USER_ACCOUNT(tenant_id, username, email, password_hash) 
VALUES( @tenantB, 'bob', 'bob @b.com', 'y');

-- Validate isolation
SELECT username FROM SECURITY.USER_ACCOUNT;            -- should show only Bob in tenant B
-- Try to peek tenant A (should be empty)
SELECT * FROM SECURITY.USER_ACCOUNT WHERE username='alice';

-- Cross-tenant insert block test (should fail)
BEGIN TRY
  INSERT INTO SECURITY.USER_ACCOUNT(tenant_id, username, email, password_hash) 
  VALUES( @tenantA, 'mallory', 'mallory @bad.com', 'z'); -- blocked by RLS BLOCK predicate
END TRY BEGIN CATCH
  PRINT ERROR_MESSAGE();
END CATCH;

-- Soft delete hides row
UPDATE SECURITY.USER_ACCOUNT SET is_deleted=1 WHERE username='bob';
SELECT * FROM SECURITY.USER_ACCOUNT WHERE username='bob'; -- empty