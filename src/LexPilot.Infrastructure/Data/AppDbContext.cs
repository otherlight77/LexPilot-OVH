using LexPilot.Domain.Clients;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Infrastructure.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<Client> Clients => Set<Client>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Client>(entity =>
        {
            entity.ToTable("clients");

            entity.HasKey(x => x.Id);

            entity.Property(x => x.FirstName)
                .HasMaxLength(150)
                .IsRequired();

            entity.Property(x => x.LastName)
                .HasMaxLength(150)
                .IsRequired();

            entity.Property(x => x.CompanyName)
                .HasMaxLength(200);

            entity.Property(x => x.Email)
                .HasMaxLength(250);

            entity.Property(x => x.Phone)
                .HasMaxLength(50);

            entity.Property(x => x.City)
                .HasMaxLength(120);

            entity.Property(x => x.PostalCode)
                .HasMaxLength(30);
        });
    }
}
