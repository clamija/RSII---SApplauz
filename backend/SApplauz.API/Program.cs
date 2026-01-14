using System.Text;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http;
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

    // Fix za Swagger generisanje kada imamo upload endpoint-e sa IFormFile.
    c.MapType<IFormFile>(() => new OpenApiSchema
    {
        Type = "string",
        Format = "binary"
    });
});

builder.Services.AddIdentityServices(builder.Configuration);

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

builder.Services.AddScoped<IClaimsTransformation, RoleClaimsTransformation>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutterApps", policy =>
    {
        if (builder.Environment.IsDevelopment())
        {
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        }
        else
        {
            policy.WithOrigins("http://localhost", "http://127.0.0.1")
                  .AllowAnyMethod()
                  .AllowAnyHeader()
                  .AllowCredentials();
        }
    });
});

builder.Services.AddHttpContextAccessor();

builder.Services.AddMemoryCache();

builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<ICurrentUserService, CurrentUserService>();
builder.Services.AddScoped<IDatabaseSeeder, DatabaseSeeder>();
    builder.Services.AddScoped<IRecommendationService, RecommendationService>();
    
    builder.Services.AddScoped<IInstitutionService, InstitutionService>();
    builder.Services.AddScoped<IGenreService, GenreService>();
    builder.Services.AddScoped<IShowService, ShowService>();
    builder.Services.AddScoped<IPerformanceService, PerformanceService>();
    builder.Services.AddScoped<IReviewService, SApplauz.Application.Services.ReviewService>();
    builder.Services.AddScoped<IOrderService, OrderService>();
    builder.Services.AddScoped<ITicketService, TicketService>();
    builder.Services.AddScoped<IReportService, ReportService>();
    
    var rabbitMQSettings = builder.Configuration.GetSection("RabbitMQ");
    builder.Services.Configure<RabbitMQSettings>(rabbitMQSettings);
    
    builder.Services.AddSingleton<IRabbitMQService, RabbitMQService>();
    
    var stripeSettings = builder.Configuration.GetSection("Stripe");
    builder.Services.Configure<StripeSettings>(stripeSettings);
    
        builder.Services.AddScoped<IStripeService, StripeService>();

builder.Services.AddHostedService<TicketExpirationService>();

System.Reflection.Assembly autoMapperAssembly = typeof(UserProfile).Assembly;
builder.Services.AddAutoMapper(autoMapperAssembly);

builder.Services.AddValidatorsFromAssemblyContaining<LoginRequestValidator>();
builder.Services.AddFluentValidationAutoValidation();
builder.Services.AddFluentValidationClientsideAdapters();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("AllowFlutterApps");

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseStaticFiles();

app.UseMiddleware<ValidationErrorHandlerMiddleware>();

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

// Seed (kontrolisano preko konfiguracije; omogućava dev okruženju da isključi seed kad je baza već postavljena)
if (builder.Configuration.GetValue<bool>("SeedOnStartup"))
{
    using var scope = app.Services.CreateScope();
    var seeder = scope.ServiceProvider.GetRequiredService<IDatabaseSeeder>();
    try
    {
        await seeder.SeedAsync();
    }
    catch (Exception ex)
    {
        // Ne ruši aplikaciju (Swagger/UI) ako je lokalna baza u nekonzistentnom stanju.
        app.Logger.LogError(ex, "Database seeding failed. API will continue running.");
    }
}

app.Run();
