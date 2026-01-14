using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using SApplauz.Domain.Entities;

namespace SApplauz.Infrastructure.Identity;

public class ApplicationDbContext : IdentityDbContext<ApplicationUser>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    // DbSets for domain entities
    public DbSet<Institution> Institutions { get; set; }
    public DbSet<Genre> Genres { get; set; }
    public DbSet<Show> Shows { get; set; }
    public DbSet<Performance> Performances { get; set; }
    public DbSet<Order> Orders { get; set; }
    public DbSet<OrderItem> OrderItems { get; set; }
    public DbSet<Ticket> Tickets { get; set; }
    public DbSet<Payment> Payments { get; set; }
    public DbSet<Review> Reviews { get; set; }
    public DbSet<RecommendationProfile> RecommendationProfiles { get; set; }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // Configure ApplicationUser
        builder.Entity<ApplicationUser>(entity =>
        {
            entity.Property(e => e.Email)
                .IsRequired()
                .HasMaxLength(256);

            entity.HasIndex(e => e.Email)
                .IsUnique();

            entity.Property(e => e.UserName)
                .IsRequired()
                .HasMaxLength(256);

            entity.HasIndex(e => e.UserName)
                .IsUnique();
            
            // InstitutionId - nullable, postavlja se samo za Admin i Blagajnik uloge
            entity.Property(e => e.InstitutionId)
                .IsRequired(false);
            
            // Navigation property za Institution
            entity.HasOne(e => e.Institution)
                .WithMany()
                .HasForeignKey(e => e.InstitutionId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // Configure Institution
        builder.Entity<Institution>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name)
                .IsRequired()
                .HasMaxLength(200);
            entity.Property(e => e.Description)
                .HasMaxLength(1000);
            entity.Property(e => e.Address)
                .HasMaxLength(500);
            entity.Property(e => e.Capacity)
                .IsRequired();
            entity.Property(e => e.ImagePath)
                .HasMaxLength(500);
            entity.Property(e => e.Website)
                .HasMaxLength(500);
        });

        // Configure Genre
        builder.Entity<Genre>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name)
                .IsRequired()
                .HasMaxLength(100);
            entity.HasIndex(e => e.Name)
                .IsUnique();
        });

        // Configure Show
        builder.Entity<Show>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Title)
                .IsRequired()
                .HasMaxLength(200);
            entity.Property(e => e.Description)
                .HasMaxLength(2000);
            entity.Property(e => e.DurationMinutes)
                .IsRequired();
            entity.Property(e => e.InstitutionId)
                .IsRequired();
            entity.Property(e => e.GenreId)
                .IsRequired();
            entity.Property(e => e.ImagePath)
                .HasMaxLength(500);

            entity.HasOne(e => e.Institution)
                .WithMany(i => i.Shows)
                .HasForeignKey(e => e.InstitutionId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.Genre)
                .WithMany(g => g.Shows)
                .HasForeignKey(e => e.GenreId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // Configure Performance
        builder.Entity<Performance>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.ShowId)
                .IsRequired();
            entity.Property(e => e.StartTime)
                .IsRequired();
            entity.Property(e => e.Price)
                .HasColumnType("decimal(18,2)")
                .IsRequired();
            entity.Property(e => e.AvailableSeats)
                .IsRequired();

            entity.HasOne(e => e.Show)
                .WithMany(s => s.Performances)
                .HasForeignKey(e => e.ShowId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(e => new { e.ShowId, e.StartTime });
        });

        // Configure Order
        builder.Entity<Order>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.UserId)
                .IsRequired()
                .HasMaxLength(450);
            entity.Property(e => e.InstitutionId)
                .IsRequired();
            entity.Property(e => e.TotalAmount)
                .HasColumnType("decimal(18,2)")
                .IsRequired();
            entity.Property(e => e.Status)
                .HasConversion<int>()
                .IsRequired();

            entity.HasOne<ApplicationUser>()
                .WithMany(u => u.Orders)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.Institution)
                .WithMany(i => i.Orders)
                .HasForeignKey(e => e.InstitutionId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(e => e.UserId);
            entity.HasIndex(e => e.CreatedAt);
        });

        // Configure OrderItem
        builder.Entity<OrderItem>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.OrderId)
                .IsRequired();
            entity.Property(e => e.PerformanceId)
                .IsRequired();
            entity.Property(e => e.Quantity)
                .IsRequired();
            entity.Property(e => e.UnitPrice)
                .HasColumnType("decimal(18,2)")
                .IsRequired();

            entity.HasOne(e => e.Order)
                .WithMany(o => o.OrderItems)
                .HasForeignKey(e => e.OrderId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Performance)
                .WithMany(p => p.OrderItems)
                .HasForeignKey(e => e.PerformanceId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // Configure Ticket
        builder.Entity<Ticket>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.OrderItemId)
                .IsRequired();
            entity.Property(e => e.QRCode)
                .IsRequired()
                .HasMaxLength(500);
            entity.Property(e => e.Status)
                .HasConversion<int>()
                .IsRequired();

            entity.HasOne(e => e.OrderItem)
                .WithMany(oi => oi.Tickets)
                .HasForeignKey(e => e.OrderItemId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => e.QRCode)
                .IsUnique();
        });

        // Configure Payment
        builder.Entity<Payment>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.OrderId)
                .IsRequired();
            entity.Property(e => e.StripePaymentIntentId)
                .HasMaxLength(500);
            entity.Property(e => e.Amount)
                .HasColumnType("decimal(18,2)")
                .IsRequired();
            entity.Property(e => e.Status)
                .HasConversion<int>()
                .IsRequired();

            entity.HasOne(e => e.Order)
                .WithMany(o => o.Payments)
                .HasForeignKey(e => e.OrderId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(e => e.StripePaymentIntentId);
            entity.HasIndex(e => e.OrderId);
        });

        // Configure Review
        builder.Entity<Review>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.UserId)
                .IsRequired()
                .HasMaxLength(450);
            entity.Property(e => e.ShowId)
                .IsRequired();
            entity.Property(e => e.Rating)
                .IsRequired();
            entity.Property(e => e.Comment)
                .HasMaxLength(2000);

            entity.HasOne<ApplicationUser>()
                .WithMany(u => u.Reviews)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.Show)
                .WithMany(s => s.Reviews)
                .HasForeignKey(e => e.ShowId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(e => new { e.UserId, e.ShowId })
                .IsUnique(); // One review per user per show

            entity.ToTable(t => t.HasCheckConstraint("CK_Review_Rating", "[Rating] >= 1 AND [Rating] <= 5"));
        });

        // Configure RecommendationProfile
        builder.Entity<RecommendationProfile>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.UserId)
                .IsRequired()
                .HasMaxLength(450);
            entity.Property(e => e.PreferredGenresJson)
                .HasMaxLength(2000);

            entity.HasOne<ApplicationUser>()
                .WithMany(u => u.RecommendationProfiles)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => e.UserId)
                .IsUnique(); // One profile per user
        });
    }
}
