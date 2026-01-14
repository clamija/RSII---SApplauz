using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;
using SApplauz.Infrastructure.Configurations;
using SApplauz.Infrastructure.Identity;
using SApplauz.Worker.Workers;

var builder = Host.CreateApplicationBuilder(args);

// Add DbContext
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection") ??
        throw new InvalidOperationException("Connection string 'DefaultConnection' not found."),
        b => b.MigrationsAssembly("SApplauz.Infrastructure")));

// Configure RabbitMQ Settings
var rabbitMQSettings = builder.Configuration.GetSection("RabbitMQ");
builder.Services.Configure<RabbitMQSettings>(rabbitMQSettings);

// Configure SMTP Settings
var smtpSettings = builder.Configuration.GetSection("SMTP");
builder.Services.Configure<SApplauz.Infrastructure.Configurations.SmtpSettings>(smtpSettings);

// Register Email Service
builder.Services.AddScoped<SApplauz.Infrastructure.Services.IEmailService, SApplauz.Infrastructure.Services.EmailService>();

// Register RabbitMQ Service
builder.Services.AddSingleton<SApplauz.Infrastructure.Services.IRabbitMQService, SApplauz.Infrastructure.Services.RabbitMQService>();

// Register Workers
builder.Services.AddHostedService<RabbitMQWorker>();
builder.Services.AddHostedService<TicketExpirationService>();

var host = builder.Build();
host.Run();
