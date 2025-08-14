// Program.cs
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.Data.SqlClient;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Prometheus;
using System.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(OpenIdConnectDefaults.AuthenticationScheme)
  .AddOpenIdConnect(OpenIdConnectDefaults.AuthenticationScheme, options =>
  {
    options.Authority = builder.Configuration["AzureAdB2C:Authority"];
    options.ClientId = builder.Configuration["AzureAdB2C:ClientId"];
    options.ClientSecret = builder.Configuration["AzureAdB2C:ClientSecret"];
    options.ResponseType = OpenIdConnectResponseType.Code;
    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.SaveTokens = true;
    options.GetClaimsFromUserInfoEndpoint = false;
    options.TokenValidationParameters.ValidateIssuer = false;
    options.TokenValidationParameters.NameClaimType = "name";
  })
  .AddJwtBearer(JwtBearerDefaults.AuthenticationScheme, options =>
  {
    options.Authority = builder.Configuration["AzureAdB2C:Authority"];
    options.Audience = builder.Configuration["AzureAdB2C:ClientId"];
    options.TokenValidationParameters.ValidateIssuer = false;
  });

builder.Services.AddAuthorization();

var app = builder.Build();

// Prometheus metrics
app.UseRouting();
app.UseHttpMetrics();
app.MapMetrics();

app.MapGet("/healthz", () => Results.Ok(new { status = "ok" }));
app.MapGet("/ready",  () => Results.Ok(new { status = "ready" }));

// B2C Authentication endpoints
app.MapGet("/login", () => Results.Challenge(new AuthenticationProperties
{
  RedirectUri = "/dashboard"
}, OpenIdConnectDefaults.AuthenticationScheme));

app.MapPost("/logout", () => Results.SignOut(new AuthenticationProperties
{
  RedirectUri = "/"
}, OpenIdConnectDefaults.AuthenticationScheme));

app.MapGet("/dashboard", (HttpContext ctx) =>
{
  var user = ctx.User;
  var claims = user.Claims.Select(c => new { c.Type, c.Value }).ToList();
  return Results.Ok(new 
  { 
    message = "Welcome to Insurance Platform!",
    user = new
    {
      id = user.FindFirst("http://schemas.microsoft.com/identity/claims/objectidentifier")?.Value,
      email = user.FindFirst("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress")?.Value,
      name = user.FindFirst("name")?.Value,
      givenName = user.FindFirst("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname")?.Value,
      surname = user.FindFirst("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname")?.Value
    },
    allClaims = claims
  });
}).RequireAuthorization();

app.MapGet("/api/security/users", async (HttpContext ctx, IConfiguration cfg) =>
{
  var b2cUserId = ctx.User.FindFirst("http://schemas.microsoft.com/identity/claims/objectidentifier")?.Value;
  var userEmail = ctx.User.FindFirst("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress")?.Value;
  var tenantId = ctx.Request.Headers["X-Tenant-Id"].FirstOrDefault() ?? "00000000-0000-0000-0000-000000000001"; // Default tenant for demo

  if (string.IsNullOrEmpty(b2cUserId))
  {
    return Results.Unauthorized();
  }

  await using var cn = new SqlConnection(cfg.GetConnectionString("Sql"));
  await cn.OpenAsync();

  // Set session context for RLS
  await using (var cmd = new SqlCommand("EXEC sys.sp_set_session_context @key=N'tenant_id', @value=@tid; EXEC sys.sp_set_session_context @key=N'user_id', @value=@uid;", cn))
  {
    cmd.Parameters.AddWithValue("@tid", Guid.Parse(tenantId));
    cmd.Parameters.AddWithValue("@uid", Guid.Parse(b2cUserId));
    await cmd.ExecuteNonQueryAsync();
  }

  var users = new List<object>();
  await using (var cmd = new SqlCommand("SELECT id, username, email, is_active, created_at FROM SECURITY.USER_ACCOUNT", cn))
  await using (var rd = await cmd.ExecuteReaderAsync(CommandBehavior.CloseConnection))
    while (await rd.ReadAsync())
      users.Add(new { id = rd.GetGuid(0), username = rd.GetString(1), email = rd.GetString(2), is_active = rd.GetBoolean(3), created_at = rd.GetDateTime(4) });

  return Results.Ok(new { currentUser = new { b2cUserId, userEmail, tenantId }, users });
}).RequireAuthorization();

app.Run();