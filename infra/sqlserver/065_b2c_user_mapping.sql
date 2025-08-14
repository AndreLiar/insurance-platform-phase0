-- B2C User Mapping Functions and Procedures

-- Function to get or create B2C user in our system
CREATE OR ALTER PROCEDURE SECURITY.sp_GetOrCreateB2CUser
  @TenantId          UNIQUEIDENTIFIER,
  @ExternalUserId    NVARCHAR(255),
  @Email             NVARCHAR(255),
  @FirstName         NVARCHAR(100) = NULL,
  @LastName          NVARCHAR(100) = NULL,
  @UserId            UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
  SET NOCOUNT ON;
  
  -- Try to find existing user by external ID
  SELECT @UserId = id 
  FROM SECURITY.USER_ACCOUNT 
  WHERE external_user_id = @ExternalUserId 
    AND auth_provider = 'AZURE_B2C'
    AND is_deleted = 0;

  -- If not found, create new user
  IF @UserId IS NULL
  BEGIN
    SET @UserId = NEWID();
    
    INSERT INTO SECURITY.USER_ACCOUNT(
      id, tenant_id, username, email, external_user_id, 
      auth_provider, first_name, last_name, password_hash
    ) VALUES (
      @UserId, @TenantId, @Email, @Email, @ExternalUserId,
      'AZURE_B2C', @FirstName, @LastName, NULL
    );
  END
  ELSE
  BEGIN
    -- Update last login and any changed info
    UPDATE SECURITY.USER_ACCOUNT 
    SET 
      last_login = SYSUTCDATETIME(),
      first_name = COALESCE(@FirstName, first_name),
      last_name = COALESCE(@LastName, last_name),
      updated_at = SYSUTCDATETIME()
    WHERE id = @UserId;
  END
END;
GO

-- View to show B2C users with their roles
CREATE OR ALTER VIEW SECURITY.vw_B2CUsers AS
SELECT 
  ua.id,
  ua.tenant_id,
  ua.email,
  ua.external_user_id as b2c_object_id,
  ua.first_name,
  ua.last_name,
  ua.is_active,
  ua.last_login,
  ua.created_at,
  STRING_AGG(r.role_name, ', ') as roles
FROM SECURITY.USER_ACCOUNT ua
LEFT JOIN SECURITY.USER_ROLE ur ON ua.id = ur.user_id AND ur.is_deleted = 0
LEFT JOIN SECURITY.ROLE r ON ur.role_id = r.id AND r.is_deleted = 0
WHERE ua.auth_provider = 'AZURE_B2C' AND ua.is_deleted = 0
GROUP BY ua.id, ua.tenant_id, ua.email, ua.external_user_id, 
         ua.first_name, ua.last_name, ua.is_active, ua.last_login, ua.created_at;
GO

-- Sample data: Create a default tenant for testing
DECLARE @DefaultTenant UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000001';

-- Insert default tenant roles if they don't exist
IF NOT EXISTS (SELECT 1 FROM SECURITY.ROLE WHERE tenant_id = @DefaultTenant AND role_name = 'USER')
BEGIN
  INSERT INTO SECURITY.ROLE(tenant_id, role_name, description, is_system_role)
  VALUES 
    (@DefaultTenant, 'USER', 'Standard user role', 1),
    (@DefaultTenant, 'ADMIN', 'Administrator role', 1);
END
GO