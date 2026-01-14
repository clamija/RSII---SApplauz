using System.Text;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using SApplauz.Application.Mappings;
using SApplauz.Application.Services;
using SApplauz.Application.Interfaces;
using SApplauz.Application.Validators;
using SApplauz.Infrastructure.Configurations;
using SApplauz.Infrastructure.Identity;
using SApplauz.Infrastructure.Services;
using SApplauz.API.Middleware;
using SApplauz.API.Filters;
using SApplauz.API.Security;
using Stripe;
using FluentValidation;
using FluentValidation.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers(options =>
{
    options.Filters.Add<ValidationFilter>();
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo 
    { 
        Title = "SApplauz API", 
        Version = "v1",
        Description = "API za SApplauz platformu - objedinjena pozorišna scena Sarajeva"
    });

    // Add JWT Authentication to Swagger
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Enter 'Bearer' [space] and then your token in the text input below.",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// Add Identity services
builder.Services.AddIdentityServices(builder.Configuration);

// Configure JWT Authentication
var jwtSettings = builder.Configuration.GetSection("JWT").Get<JwtSettings>() 
    ?? throw new InvalidOperationException("JWT settings not found in configuration.");

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings.SecretKey)),
        ValidateIssuer = true,
        ValidIssuer = jwtSettings.Issuer,
        ValidateAudience = true,
        ValidAudience = jwtSettings.Audience,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero
    };
});

builder.Services.AddAuthorization();

// Normalize role claims (case-insensitive roles support)
builder.Services.AddScoped<IClaimsTransformation, RoleClaimsTransformation>();

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutterApps", policy =>
    {
        if (builder.Environment.IsDevelopment())
        {
            // U development modu dozvoli sve origin-e (samo za development!)
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        }
        else
        {
            // U production modu koristi striktnu konfiguraciju
            policy.WithOrigins("http://localhost", "http://127.0.0.1")
                  .AllowAnyMethod()
                  .AllowAnyHeader()
                  .AllowCredentials();
        }
    });
});

// Add HttpContextAccessor for CurrentUserService
builder.Services.AddHttpContextAccessor();

// Add Memory Cache for RecommendationService
builder.Services.AddMemoryCache();

// Add Application services
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<ICurrentUserService, CurrentUserService>();
builder.Services.AddScoped<IDatabaseSeeder, DatabaseSeeder>();
    // Register RecommendationService first (it's used by other services)
    builder.Services.AddScoped<IRecommendationService, RecommendationService>();
    
    builder.Services.AddScoped<IInstitutionService, InstitutionService>();
    builder.Services.AddScoped<IGenreService, GenreService>();
    builder.Services.AddScoped<IShowService, ShowService>();
    builder.Services.AddScoped<IPerformanceService, PerformanceService>();
    builder.Services.AddScoped<IReviewService, SApplauz.Application.Services.ReviewService>();
    builder.Services.AddScoped<IOrderService, OrderService>();
    builder.Services.AddScoped<ITicketService, TicketService>();
    builder.Services.AddScoped<IReportService, ReportService>();
    
    // Configure RabbitMQ Settings
    var rabbitMQSettings = builder.Configuration.GetSection("RabbitMQ");
    builder.Services.Configure<RabbitMQSettings>(rabbitMQSettings);
    
    // Register RabbitMQ Service as Singleton (connection should be shared)
    builder.Services.AddSingleton<IRabbitMQService, RabbitMQService>();
    
    // Configure Stripe Settings
    var stripeSettings = builder.Configuration.GetSection("Stripe");
    builder.Services.Configure<StripeSettings>(stripeSettings);
    
    // Register Stripe Service
    builder.Services.AddScoped<IStripeService, StripeService>();

// Add Background Services
builder.Services.AddHostedService<TicketExpirationService>();

// Add AutoMapper - Assembly je već dostupan kroz Application projekat
System.Reflection.Assembly autoMapperAssembly = typeof(UserProfile).Assembly;
builder.Services.AddAutoMapper(autoMapperAssembly);

// Add FluentValidation
builder.Services.AddValidatorsFromAssemblyContaining<LoginRequestValidator>();
builder.Services.AddFluentValidationAutoValidation();
builder.Services.AddFluentValidationClientsideAdapters();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// CORS mora biti PRIJE UseHttpsRedirection
app.UseCors("AllowFlutterApps");

// U development modu ne koristimo HTTPS redirection da bi Flutter mogao pristupiti preko HTTP
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

// Enable static files (za serviranje slika iz wwwroot/images)
app.UseStaticFiles();

// Add Validation Error Handler Middleware
app.UseMiddleware<ValidationErrorHandlerMiddleware>();

// Eksplicitno rukovanje OPTIONS zahtjevima (preflight)
app.Use(async (context, next) =>
{
    if (context.Request.Method == "OPTIONS")
    {
        context.Response.StatusCode = 204;
        await context.Response.CompleteAsync();
        return;
    }
    await next();
});

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Seed database on startup (Development ili eksplicitno kroz config)
if (app.Environment.IsDevelopment() || builder.Configuration.GetValue<bool>("SeedOnStartup"))
{
    using var scope = app.Services.CreateScope();
    var seeder = scope.ServiceProvider.GetRequiredService<IDatabaseSeeder>();
    await seeder.SeedAsync();
}

app.Run();
