-- Session helpers: your API should set these per request.
-- EXEC sys.sp_set_session_context @key=N'tenant_id', @value=@TenantId; 
-- EXEC sys.sp_set_session_context @key=N'user_id',   @value=@UserId;
-- Optional: set bypass for ops dashboards
-- EXEC sys.sp_set_session_context @key=N'bypass_rls', @value=1;

-- RLS predicate functions
CREATE FUNCTION SECURITY.fn_rls_tenant_match( @tenant_id UNIQUEIDENTIFIER)
RETURNS TABLE WITH SCHEMABINDING
AS RETURN
  SELECT 1 AS fn_result
  WHERE (CAST(SESSION_CONTEXT(N'bypass_rls') AS NVARCHAR(10)) = N'1')
     OR ( @tenant_id = CAST(SESSION_CONTEXT(N'tenant_id') AS UNIQUEIDENTIFIER));

CREATE FUNCTION SECURITY.fn_rls_not_deleted( @is_deleted BIT)
RETURNS TABLE WITH SCHEMABINDING
AS RETURN
  SELECT 1 AS fn_result
  WHERE @is_deleted = CONVERT(BIT, 0);
GO

-- Apply a single policy with multiple predicates across all tenant tables
CREATE SECURITY POLICY SECURITY.TenantFilter
ADD FILTER PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON SECURITY.USER_ACCOUNT,
ADD FILTER PREDICATE SECURITY.fn_rls_not_deleted(is_deleted)  ON SECURITY.USER_ACCOUNT,

ADD FILTER PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON SECURITY.ROLE,
ADD FILTER PREDICATE SECURITY.fn_rls_not_deleted(is_deleted)  ON SECURITY.ROLE,

ADD FILTER PREDICATE SECURITY.fn_rls_not_deleted(is_deleted)  ON SECURITY.PERMISSION, -- no tenant here
-- (PERMISSION is global; omit tenant predicate)

ADD FILTER PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON COMMON.CODE_SET,
ADD FILTER PREDICATE SECURITY.fn_rls_not_deleted(is_deleted)  ON COMMON.CODE_SET,

ADD FILTER PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON COMMON.CODE_VALUE,
ADD FILTER PREDICATE SECURITY.fn_rls_not_deleted(is_deleted)  ON COMMON.CODE_VALUE,

ADD FILTER PREDICATE SECURITY.fn_rls_not_deleted(is_deleted)  ON COMMON.COUNTRY,
ADD FILTER PREDICATE SECURITY.fn_rls_not_deleted(is_deleted)  ON COMMON.CURRENCY,
ADD FILTER PREDICATE SECURITY.fn_rls_not_deleted(is_deleted)  ON COMMON.LANGUAGE,

ADD FILTER PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON OPS.AUDIT_LOG,
ADD FILTER PREDICATE SECURITY.fn_rls_not_deleted(is_deleted)  ON OPS.AUDIT_LOG,

ADD FILTER PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON OPS.OUTBOX_EVENT,
ADD FILTER PREDICATE SECURITY.fn_rls_not_deleted(is_deleted)  ON OPS.OUTBOX_EVENT,

ADD FILTER PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON OPS.INTEGRATION_ENDPOINT,
ADD FILTER PREDICATE SECURITY.fn_rls_not_deleted(is_deleted)  ON OPS.INTEGRATION_ENDPOINT,

ADD FILTER PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON DOCS.DOCUMENT,
ADD FILTER PREDICATE SECURITY.fn_rls_not_deleted(is_deleted)  ON DOCS.DOCUMENT

WITH (STATE = ON);
GO

-- Block predicates to prevent cross-tenant writes
ALTER SECURITY POLICY SECURITY.TenantFilter
ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON SECURITY.USER_ACCOUNT  AFTER INSERT,
ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON SECURITY.USER_ACCOUNT  BEFORE UPDATE,

ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON SECURITY.ROLE          AFTER INSERT,
ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON SECURITY.ROLE          BEFORE UPDATE,

ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON COMMON.CODE_SET        AFTER INSERT,
ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON COMMON.CODE_SET        BEFORE UPDATE,

ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON COMMON.CODE_VALUE      AFTER INSERT,
ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON COMMON.CODE_VALUE      BEFORE UPDATE,

ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON OPS.OUTBOX_EVENT       AFTER INSERT,
ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON OPS.OUTBOX_EVENT       BEFORE UPDATE,

ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON OPS.INTEGRATION_ENDPOINT AFTER INSERT,
ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON OPS.INTEGRATION_ENDPOINT BEFORE UPDATE,

ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON DOCS.DOCUMENT          AFTER INSERT,
ADD BLOCK PREDICATE SECURITY.fn_rls_tenant_match(tenant_id) ON DOCS.DOCUMENT          BEFORE UPDATE;
GO