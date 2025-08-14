// Program.cs
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Data.SqlClient;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Data;
using Prometheus;
using BC = BCrypt.Net.BCrypt;

var builder = WebApplication.CreateBuilder(args);

var jwtSettings = builder.Configuration.GetSection("JwtSettings");
var secretKey = jwtSettings["SecretKey"]!;
var key = Encoding.ASCII.GetBytes(secretKey);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
  .AddJwtBearer(options =>
  {
    options.TokenValidationParameters = new TokenValidationParameters
    {
      ValidateIssuerSigningKey = true,
      IssuerSigningKey = new SymmetricSecurityKey(key),
      ValidateIssuer = true,
      ValidIssuer = jwtSettings["Issuer"],
      ValidateAudience = true,
      ValidAudience = jwtSettings["Audience"],
      ValidateLifetime = true,
      ClockSkew = TimeSpan.Zero
    };
  });

builder.Services.AddAuthorization();

var app = builder.Build();

// Prometheus metrics
app.UseRouting();
app.UseHttpMetrics();
app.UseAuthentication();
app.UseAuthorization();
app.MapMetrics();

app.MapGet("/healthz", () => Results.Ok(new { status = "ok" }));
app.MapGet("/ready", async (IConfiguration cfg) =>
{
  try
  {
    await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
    await cn.OpenAsync();
    
    // Test RLS is working
    await using var cmd = new SqlCommand("SELECT COUNT(*) FROM sys.security_policies WHERE name = 'TenantFilter' AND is_enabled = 1", cn);
    var rlsEnabled = (int)await cmd.ExecuteScalarAsync()! > 0;
    
    return Results.Ok(new { 
      status = "ready", 
      database = "connected", 
      rls = rlsEnabled ? "enabled" : "disabled",
      timestamp = DateTime.UtcNow 
    });
  }
  catch (Exception ex)
  {
    return Results.Problem($"Database connection failed: {ex.Message}");
  }
});

// JWT Authentication endpoints
app.MapPost("/auth/register", async (HttpContext ctx, IConfiguration cfg) =>
{
  var request = await ctx.Request.ReadFromJsonAsync<RegisterRequest>();
  if (request == null || string.IsNullOrEmpty(request.Email) || string.IsNullOrEmpty(request.Password))
    return Results.BadRequest(new { message = "Email and password are required" });

  var tenantId = ctx.Request.Headers["X-Tenant-Id"].FirstOrDefault() ?? "00000000-0000-0000-0000-000000000001";

  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();

  // Check if user already exists
  await using (var cmd = new SqlCommand("SELECT COUNT(*) FROM SECURITY.USER_ACCOUNT WHERE email = @email AND is_deleted = 0", cn))
  {
    cmd.Parameters.AddWithValue("@email", request.Email);
    var count = await cmd.ExecuteScalarAsync();
    var exists = count != null && (int)count > 0;
    if (exists) return Results.Conflict(new { message = "User already exists" });
  }

  // Create new user
  var userId = Guid.NewGuid();
  var passwordHash = BC.HashPassword(request.Password);

  await using (var cmd = new SqlCommand(@"
    INSERT INTO SECURITY.USER_ACCOUNT(id, tenant_id, username, email, password_hash, first_name, last_name, auth_provider)
    VALUES(@id, @tenantId, @email, @email, @passwordHash, @firstName, @lastName, 'LOCAL')", cn))
  {
    cmd.Parameters.AddWithValue("@id", userId);
    cmd.Parameters.AddWithValue("@tenantId", Guid.Parse(tenantId));
    cmd.Parameters.AddWithValue("@email", request.Email);
    cmd.Parameters.AddWithValue("@passwordHash", passwordHash);
    cmd.Parameters.AddWithValue("@firstName", request.FirstName ?? "");
    cmd.Parameters.AddWithValue("@lastName", request.LastName ?? "");
    await cmd.ExecuteNonQueryAsync();
  }

  return Results.Ok(new { message = "User created successfully", userId = userId.ToString() });
});

app.MapPost("/auth/login", async (HttpContext ctx, IConfiguration cfg) =>
{
  var request = await ctx.Request.ReadFromJsonAsync<LoginRequest>();
  if (request == null || string.IsNullOrEmpty(request.Email) || string.IsNullOrEmpty(request.Password))
    return Results.BadRequest(new { message = "Email and password are required" });

  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();

  // Get user
  await using var cmd = new SqlCommand(@"
    SELECT id, tenant_id, email, password_hash, first_name, last_name, is_active 
    FROM SECURITY.USER_ACCOUNT 
    WHERE email = @email AND auth_provider = 'LOCAL' AND is_deleted = 0", cn);
  cmd.Parameters.AddWithValue("@email", request.Email);

  await using var reader = await cmd.ExecuteReaderAsync();
  if (!await reader.ReadAsync())
    return Results.Unauthorized();

  var userId = reader.GetGuid(0);
  var tenantId = reader.GetGuid(1);
  var email = reader.GetString(2);
  var storedHash = reader.GetString(3);
  var firstName = reader.IsDBNull(4) ? "" : reader.GetString(4);
  var lastName = reader.IsDBNull(5) ? "" : reader.GetString(5);
  var isActive = reader.GetBoolean(6);

  if (!isActive || !BC.Verify(request.Password, storedHash))
    return Results.Unauthorized();

  // Generate JWT token
  var jwtSettings = cfg.GetSection("JwtSettings");
  var secretKey = jwtSettings["SecretKey"]!;
  var key = Encoding.ASCII.GetBytes(secretKey);

  var tokenDescriptor = new SecurityTokenDescriptor
  {
    Subject = new ClaimsIdentity(new[]
    {
      new Claim("user_id", userId.ToString()),
      new Claim("tenant_id", tenantId.ToString()),
      new Claim("email", email),
      new Claim("name", $"{firstName} {lastName}".Trim()),
      new Claim("first_name", firstName),
      new Claim("last_name", lastName)
    }),
    Expires = DateTime.UtcNow.AddMinutes(int.Parse(jwtSettings["ExpirationMinutes"]!)),
    Issuer = jwtSettings["Issuer"],
    Audience = jwtSettings["Audience"],
    SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature)
  };

  var tokenHandler = new JwtSecurityTokenHandler();
  var token = tokenHandler.CreateToken(tokenDescriptor);

  return Results.Ok(new 
  { 
    token = tokenHandler.WriteToken(token),
    user = new { userId, tenantId, email, firstName, lastName },
    expiresAt = tokenDescriptor.Expires
  });
});

app.MapGet("/dashboard", (HttpContext ctx) =>
{
  var user = ctx.User;
  return Results.Ok(new 
  { 
    message = "Welcome to Insurance Platform!",
    user = new
    {
      id = user.FindFirst("user_id")?.Value,
      tenantId = user.FindFirst("tenant_id")?.Value,
      email = user.FindFirst("email")?.Value,
      name = user.FindFirst("name")?.Value,
      firstName = user.FindFirst("first_name")?.Value,
      lastName = user.FindFirst("last_name")?.Value
    }
  });
}).RequireAuthorization();

app.MapGet("/api/security/users", async (HttpContext ctx, IConfiguration cfg) =>
{
  var userId = ctx.User.FindFirst("user_id")?.Value;
  var tenantId = ctx.User.FindFirst("tenant_id")?.Value;
  var userEmail = ctx.User.FindFirst("email")?.Value;

  if (string.IsNullOrEmpty(userId) || string.IsNullOrEmpty(tenantId))
  {
    return Results.Unauthorized();
  }

  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();

  // Set session context for RLS
  await using (var cmd = new SqlCommand("EXEC sys.sp_set_session_context @key=N'tenant_id', @value=@tid; EXEC sys.sp_set_session_context @key=N'user_id', @value=@uid;", cn))
  {
    cmd.Parameters.AddWithValue("@tid", Guid.Parse(tenantId));
    cmd.Parameters.AddWithValue("@uid", Guid.Parse(userId));
    await cmd.ExecuteNonQueryAsync();
  }

  var users = new List<object>();
  await using (var cmd = new SqlCommand("SELECT id, username, email, is_active, created_at, auth_provider FROM SECURITY.USER_ACCOUNT", cn))
  await using (var rd = await cmd.ExecuteReaderAsync(CommandBehavior.CloseConnection))
    while (await rd.ReadAsync())
      users.Add(new { 
        id = rd.GetGuid(0), 
        username = rd.GetString(1), 
        email = rd.GetString(2), 
        is_active = rd.GetBoolean(3), 
        created_at = rd.GetDateTime(4),
        auth_provider = rd.GetString(5)
      });

  return Results.Ok(new { currentUser = new { userId, userEmail, tenantId }, users });
}).RequireAuthorization();

// CRUD Endpoints for Phase 0

// Roles CRUD
app.MapGet("/api/roles", async (HttpContext ctx, IConfiguration cfg) =>
{
  var tenantId = ctx.User.FindFirst("tenant_id")?.Value;
  if (string.IsNullOrEmpty(tenantId)) return Results.Unauthorized();
  
  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();
  
  await using var cmd = new SqlCommand("EXEC sys.sp_set_session_context @key=N'tenant_id', @value=@tid", cn);
  cmd.Parameters.AddWithValue("@tid", Guid.Parse(tenantId));
  await cmd.ExecuteNonQueryAsync();
  
  var roles = new List<object>();
  await using (var selectCmd = new SqlCommand("SELECT id, role_name, description, is_system_role FROM SECURITY.ROLE", cn))
  await using (var reader = await selectCmd.ExecuteReaderAsync())
  {
    while (await reader.ReadAsync())
      roles.Add(new { 
        id = reader.GetGuid(0),
        roleName = reader.GetString(1),
        description = reader.IsDBNull(2) ? null : reader.GetString(2),
        isSystemRole = reader.GetBoolean(3)
      });
  }
  
  return Results.Ok(roles);
}).RequireAuthorization();

app.MapPost("/api/roles", async (HttpContext ctx, IConfiguration cfg) =>
{
  var request = await ctx.Request.ReadFromJsonAsync<CreateRoleRequest>();
  if (request == null || string.IsNullOrEmpty(request.RoleName))
    return Results.BadRequest(new { message = "Role name is required" });
  
  var tenantId = ctx.User.FindFirst("tenant_id")?.Value;
  var userId = ctx.User.FindFirst("user_id")?.Value;
  if (string.IsNullOrEmpty(tenantId)) return Results.Unauthorized();
  
  // Check if user has permission to create roles
  if (!await HasPermission(ctx, cfg, "roles.create"))
    return Results.Forbid();
  
  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();
  
  await using var cmd = new SqlCommand("EXEC sys.sp_set_session_context @key=N'tenant_id', @value=@tid; EXEC sys.sp_set_session_context @key=N'user_id', @value=@uid", cn);
  cmd.Parameters.AddWithValue("@tid", Guid.Parse(tenantId));
  cmd.Parameters.AddWithValue("@uid", Guid.Parse(userId!));
  await cmd.ExecuteNonQueryAsync();
  
  var roleId = Guid.NewGuid();
  await using (var insertCmd = new SqlCommand(@"
    INSERT INTO SECURITY.ROLE(id, tenant_id, role_name, description, is_system_role)
    VALUES(@id, @tenantId, @roleName, @description, 0)", cn))
  {
    insertCmd.Parameters.AddWithValue("@id", roleId);
    insertCmd.Parameters.AddWithValue("@tenantId", Guid.Parse(tenantId));
    insertCmd.Parameters.AddWithValue("@roleName", request.RoleName);
    insertCmd.Parameters.AddWithValue("@description", request.Description ?? (object)DBNull.Value);
    await insertCmd.ExecuteNonQueryAsync();
  }
  
  return Results.Created($"/api/roles/{roleId}", new { id = roleId, roleName = request.RoleName, description = request.Description });
}).RequireAuthorization();

// Code Sets CRUD
app.MapGet("/api/codesets", async (HttpContext ctx, IConfiguration cfg) =>
{
  var tenantId = ctx.User.FindFirst("tenant_id")?.Value;
  if (string.IsNullOrEmpty(tenantId)) return Results.Unauthorized();
  
  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();
  
  await using var cmd = new SqlCommand("EXEC sys.sp_set_session_context @key=N'tenant_id', @value=@tid", cn);
  cmd.Parameters.AddWithValue("@tid", Guid.Parse(tenantId));
  await cmd.ExecuteNonQueryAsync();
  
  var codeSets = new List<object>();
  await using (var selectCmd = new SqlCommand("SELECT id, code_set_name, description, is_active FROM COMMON.CODE_SET", cn))
  await using (var reader = await selectCmd.ExecuteReaderAsync())
  {
    while (await reader.ReadAsync())
      codeSets.Add(new { 
        id = reader.GetGuid(0),
        codeSetName = reader.GetString(1),
        description = reader.IsDBNull(2) ? null : reader.GetString(2),
        isActive = reader.GetBoolean(3)
      });
  }
  
  return Results.Ok(codeSets);
}).RequireAuthorization();

app.MapPost("/api/codesets", async (HttpContext ctx, IConfiguration cfg) =>
{
  var request = await ctx.Request.ReadFromJsonAsync<CreateCodeSetRequest>();
  if (request == null || string.IsNullOrEmpty(request.CodeSetName))
    return Results.BadRequest(new { message = "Code set name is required" });
  
  var tenantId = ctx.User.FindFirst("tenant_id")?.Value;
  var userId = ctx.User.FindFirst("user_id")?.Value;
  if (string.IsNullOrEmpty(tenantId)) return Results.Unauthorized();
  
  if (!await HasPermission(ctx, cfg, "codesets.create"))
    return Results.Forbid();
  
  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();
  
  await using var cmd = new SqlCommand("EXEC sys.sp_set_session_context @key=N'tenant_id', @value=@tid; EXEC sys.sp_set_session_context @key=N'user_id', @value=@uid", cn);
  cmd.Parameters.AddWithValue("@tid", Guid.Parse(tenantId));
  cmd.Parameters.AddWithValue("@uid", Guid.Parse(userId!));
  await cmd.ExecuteNonQueryAsync();
  
  var codeSetId = Guid.NewGuid();
  await using (var insertCmd = new SqlCommand(@"
    INSERT INTO COMMON.CODE_SET(id, tenant_id, code_set_name, description)
    VALUES(@id, @tenantId, @codeSetName, @description)", cn))
  {
    insertCmd.Parameters.AddWithValue("@id", codeSetId);
    insertCmd.Parameters.AddWithValue("@tenantId", Guid.Parse(tenantId));
    insertCmd.Parameters.AddWithValue("@codeSetName", request.CodeSetName);
    insertCmd.Parameters.AddWithValue("@description", request.Description ?? (object)DBNull.Value);
    await insertCmd.ExecuteNonQueryAsync();
  }
  
  return Results.Created($"/api/codesets/{codeSetId}", new { id = codeSetId, codeSetName = request.CodeSetName, description = request.Description });
}).RequireAuthorization();

// Read-only endpoints for global catalogs
app.MapGet("/api/countries", async (IConfiguration cfg) =>
{
  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();
  
  var countries = new List<object>();
  await using (var cmd = new SqlCommand("SELECT id, iso2_code, iso3_code, country_name FROM COMMON.COUNTRY WHERE is_active = 1", cn))
  await using (var reader = await cmd.ExecuteReaderAsync())
  {
    while (await reader.ReadAsync())
      countries.Add(new { 
        id = reader.GetGuid(0),
        iso2Code = reader.GetString(1),
        iso3Code = reader.GetString(2),
        countryName = reader.GetString(3)
      });
  }
  
  return Results.Ok(countries);
});

app.MapGet("/api/currencies", async (IConfiguration cfg) =>
{
  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();
  
  var currencies = new List<object>();
  await using (var cmd = new SqlCommand("SELECT id, currency_code, currency_name, symbol, decimal_places FROM COMMON.CURRENCY WHERE is_active = 1", cn))
  await using (var reader = await cmd.ExecuteReaderAsync())
  {
    while (await reader.ReadAsync())
      currencies.Add(new { 
        id = reader.GetGuid(0),
        currencyCode = reader.GetString(1),
        currencyName = reader.GetString(2),
        symbol = reader.IsDBNull(3) ? null : reader.GetString(3),
        decimalPlaces = reader.GetInt32(4)
      });
  }
  
  return Results.Ok(currencies);
});

app.MapGet("/api/languages", async (IConfiguration cfg) =>
{
  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();
  
  var languages = new List<object>();
  await using (var cmd = new SqlCommand("SELECT id, language_code, language_name, native_name FROM COMMON.LANGUAGE WHERE is_active = 1", cn))
  await using (var reader = await cmd.ExecuteReaderAsync())
  {
    while (await reader.ReadAsync())
      languages.Add(new { 
        id = reader.GetGuid(0),
        languageCode = reader.GetString(1),
        languageName = reader.GetString(2),
        nativeName = reader.IsDBNull(3) ? null : reader.GetString(3)
      });
  }
  
  return Results.Ok(languages);
});

// Audit and Outbox endpoints for monitoring
app.MapGet("/api/audit-logs", async (HttpContext ctx, IConfiguration cfg) =>
{
  var tenantId = ctx.User.FindFirst("tenant_id")?.Value;
  if (string.IsNullOrEmpty(tenantId)) return Results.Unauthorized();
  
  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();
  
  await using var cmd = new SqlCommand("EXEC sys.sp_set_session_context @key=N'tenant_id', @value=@tid", cn);
  cmd.Parameters.AddWithValue("@tid", Guid.Parse(tenantId));
  await cmd.ExecuteNonQueryAsync();
  
  var auditLogs = new List<object>();
  await using (var selectCmd = new SqlCommand(@"
    SELECT TOP 20 table_name, record_id, operation, changed_by, change_date, old_values, new_values
    FROM OPS.AUDIT_LOG 
    ORDER BY change_date DESC", cn))
  await using (var reader = await selectCmd.ExecuteReaderAsync())
  {
    while (await reader.ReadAsync())
      auditLogs.Add(new { 
        tableName = reader.GetString(0),
        recordId = reader.IsDBNull(1) ? null : reader.GetGuid(1),
        operation = reader.GetString(2),
        changedBy = reader.IsDBNull(3) ? null : reader.GetGuid(3),
        changeDate = reader.GetDateTime(4),
        oldValues = reader.IsDBNull(5) ? null : reader.GetString(5),
        newValues = reader.IsDBNull(6) ? null : reader.GetString(6)
      });
  }
  
  return Results.Ok(auditLogs);
}).RequireAuthorization();

app.MapGet("/api/outbox-events", async (HttpContext ctx, IConfiguration cfg) =>
{
  var tenantId = ctx.User.FindFirst("tenant_id")?.Value;
  if (string.IsNullOrEmpty(tenantId)) return Results.Unauthorized();
  
  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();
  
  await using var cmd = new SqlCommand("EXEC sys.sp_set_session_context @key=N'tenant_id', @value=@tid", cn);
  cmd.Parameters.AddWithValue("@tid", Guid.Parse(tenantId));
  await cmd.ExecuteNonQueryAsync();
  
  var outboxEvents = new List<object>();
  await using (var selectCmd = new SqlCommand(@"
    SELECT TOP 20 event_type, status, retry_count, created_at, processed_at, event_data
    FROM OPS.OUTBOX_EVENT 
    ORDER BY created_at DESC", cn))
  await using (var reader = await selectCmd.ExecuteReaderAsync())
  {
    while (await reader.ReadAsync())
      outboxEvents.Add(new { 
        eventType = reader.GetString(0),
        status = reader.GetString(1),
        retryCount = reader.GetInt32(2),
        createdAt = reader.GetDateTime(3),
        processedAt = reader.IsDBNull(4) ? null : reader.GetDateTime(4),
        eventData = reader.GetString(5)
      });
  }
  
  return Results.Ok(outboxEvents);
}).RequireAuthorization();

// Permission check helper
async Task<bool> HasPermission(HttpContext ctx, IConfiguration cfg, string permission)
{
  var userId = ctx.User.FindFirst("user_id")?.Value;
  var tenantId = ctx.User.FindFirst("tenant_id")?.Value;
  
  if (string.IsNullOrEmpty(userId) || string.IsNullOrEmpty(tenantId)) return false;
  
  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();
  
  await using var cmd = new SqlCommand(@"
    SELECT COUNT(*) FROM SECURITY.USER_ROLE ur
    JOIN SECURITY.ROLE_PERMISSION rp ON ur.role_id = rp.role_id
    JOIN SECURITY.PERMISSION p ON rp.permission_id = p.id
    WHERE ur.user_id = @userId AND p.permission_name = @permission 
      AND ur.is_deleted = 0 AND rp.is_deleted = 0 AND p.is_deleted = 0", cn);
  
  cmd.Parameters.AddWithValue("@userId", Guid.Parse(userId));
  cmd.Parameters.AddWithValue("@permission", permission);
  
  var count = (int)await cmd.ExecuteScalarAsync()!;
  return count > 0;
}

app.Run();

// Request models
public record RegisterRequest(string Email, string Password, string? FirstName = null, string? LastName = null);
public record LoginRequest(string Email, string Password);
public record CreateRoleRequest(string RoleName, string? Description = null);
public record CreateCodeSetRequest(string CodeSetName, string? Description = null);