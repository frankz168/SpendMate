using Serilog;
using System.IO;
using Microsoft.AspNetCore.Authentication.Cookies;

var builder = WebApplication.CreateBuilder(args);

#region ================= LOGGING (ABSOLUTE PATH)

var logDir = "/Users/frankz168/SpendMate/logs";
Directory.CreateDirectory(logDir);

var logPath = Path.Combine(logDir, "spendmate.log");

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.Console()
    .WriteTo.File(
        logPath,
        rollingInterval: RollingInterval.Day,
        retainedFileCountLimit: 7,
        outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss} [{Level}] {Message}{NewLine}{Exception}"
    )
    .CreateLogger();

builder.Host.UseSerilog();

#endregion

#region ================= SERVICES

builder.Services.AddControllersWithViews();

builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Auth/Login";
        options.LogoutPath = "/Auth/Logout";
        options.ExpireTimeSpan = TimeSpan.FromDays(30);
    });

// DB & CONFIG
builder.Services.AddSingleton<DbConnectionFactory>();
builder.Services.AddScoped<ConfigRepository>();

// DASHBOARD
builder.Services.AddScoped<DashboardRepository>();
builder.Services.AddScoped<DashboardService>();

// USER
builder.Services.AddScoped<UserRepository>();

// TRANSACTION
builder.Services.AddScoped<TransactionRepository>();
builder.Services.AddScoped<TransactionService>();

// BUDGET & MASTER DATA
builder.Services.AddScoped<BudgetRepository>();
builder.Services.AddScoped<CategoryRepository>();

// REPORT + EMAIL
builder.Services.AddScoped<EmailService>();
builder.Services.AddScoped<ReportRepository>();
builder.Services.AddScoped<ReportService>();

// SCHEDULER
builder.Services.AddHostedService<ReportSchedulerService>();

#endregion

var app = builder.Build();

#region ================= PIPELINE

app.UseSerilogRequestLogging();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapStaticAssets();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}")
    .WithStaticAssets();

#endregion

app.Run();