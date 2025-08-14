-- Helper to stringify rows (lightweight)
CREATE OR ALTER FUNCTION OPS.fn_row_to_json( @table NVARCHAR(256), @id UNIQUEIDENTIFIER)
RETURNS NVARCHAR(MAX)
AS
BEGIN
  DECLARE @json NVARCHAR(MAX);
  DECLARE @sql NVARCHAR(MAX) = 
    N'SELECT @j = (SELECT * FROM ' + @table + ' WITH (NOLOCK) WHERE id = @id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);';
  EXEC sp_executesql @sql, N' @id UNIQUEIDENTIFIER, @j NVARCHAR(MAX) OUTPUT', @id=@id, @j=@json OUTPUT;
  RETURN @json;
END;
GO

-- USER_ACCOUNT trigger
CREATE OR ALTER TRIGGER SECURITY.trg_user_account_audit_outbox
ON SECURITY.USER_ACCOUNT
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @op NVARCHAR(10), @tenant UNIQUEIDENTIFIER, @uid UNIQUEIDENTIFIER, @old NVARCHAR(MAX), @new NVARCHAR(MAX);

  IF EXISTS(SELECT 1 FROM inserted) AND EXISTS(SELECT 1 FROM deleted) SET @op = N'UPDATE';
  ELSE IF EXISTS(SELECT 1 FROM inserted) SET @op = N'INSERT';
  ELSE SET @op = N'DELETE';

  SELECT TOP 1 @tenant = COALESCE(i.tenant_id, d.tenant_id),
               @uid    = COALESCE(i.id, d.id)
  FROM inserted i
  FULL JOIN deleted d ON 1=0;

  SET @old = (SELECT TOP 1 * FROM deleted FOR JSON AUTO);
  SET @new = (SELECT TOP 1 * FROM inserted FOR JSON AUTO);

  INSERT INTO OPS.AUDIT_LOG(tenant_id, table_name, record_id, operation, old_values, new_values, changed_by)
  VALUES( @tenant, N'SECURITY.USER_ACCOUNT', @uid, @op, @old, @new, CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER));

  IF @op IN (N'INSERT', N'UPDATE')
    INSERT INTO OPS.OUTBOX_EVENT(tenant_id, event_type, event_data)
    VALUES( @tenant, N'UserAccount.' + @op,
           JSON_MODIFY(COALESCE( @new, N'{}'), '$.eventId', CAST(NEWID() AS NVARCHAR(36))));
END;
GO

-- USER_ROLE trigger -> RoleAssigned event
CREATE OR ALTER TRIGGER SECURITY.trg_user_role_outbox
ON SECURITY.USER_ROLE
AFTER INSERT
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @tenant UNIQUEIDENTIFIER, @payload NVARCHAR(MAX);
  SELECT TOP 1 @tenant = ua.tenant_id,
               @payload = (SELECT ur.id AS user_role_id, ur.user_id, ur.role_id, ur.assigned_date
                           FROM inserted ur FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
  FROM inserted i
  JOIN SECURITY.USER_ACCOUNT ua ON ua.id = i.user_id;

  INSERT INTO OPS.OUTBOX_EVENT(tenant_id, event_type, event_data)
  VALUES( @tenant, N'RoleAssigned', @payload);
END;
GO