using LexPilot.Domain.Clients;
using LexPilot.Domain.Dossiers;
using LexPilot.Domain.Documents;
using LexPilot.Domain.Taches;
using LexPilot.Domain.Utilisateurs;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Infrastructure.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) {}

    public DbSet<Client> Clients => Set<Client>();
    public DbSet<Dossier> Dossiers => Set<Dossier>();
    public DbSet<Document> Documents => Set<Document>();
    public DbSet<Tache> Taches => Set<Tache>();
    public DbSet<Utilisateur> Utilisateurs => Set<Utilisateur>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Client>(entity =>
        {
            entity.ToTable("clients");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.FirstName).HasMaxLength(150).IsRequired();
            entity.Property(x => x.LastName).HasMaxLength(150).IsRequired();
            entity.Property(x => x.CompanyName).HasMaxLength(200);
            entity.Property(x => x.Email).HasMaxLength(250);
            entity.Property(x => x.Phone).HasMaxLength(50);
            entity.Property(x => x.City).HasMaxLength(120);
            entity.Property(x => x.PostalCode).HasMaxLength(30);
        });

        modelBuilder.Entity<Dossier>(entity =>
        {
            entity.ToTable("dossiers");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Numero).HasMaxLength(80).IsRequired();
            entity.Property(x => x.Titre).HasMaxLength(250).IsRequired();
            entity.Property(x => x.TypeAffaire).HasMaxLength(120);
            entity.Property(x => x.Statut).HasMaxLength(80);
            entity.Property(x => x.Juridiction).HasMaxLength(200);
            entity.HasOne(x => x.Client)
                .WithMany()
                .HasForeignKey(x => x.ClientId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Document>(entity =>
        {
            entity.ToTable("documents");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.FileName).HasMaxLength(260).IsRequired();
            entity.Property(x => x.OriginalFileName).HasMaxLength(260).IsRequired();
            entity.Property(x => x.ContentType).HasMaxLength(120);
            entity.Property(x => x.StoragePath).HasMaxLength(500).IsRequired();
            entity.Property(x => x.Category).HasMaxLength(120);
            entity.HasOne(x => x.Dossier)
                .WithMany()
                .HasForeignKey(x => x.DossierId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Tache>(entity =>
        {
            entity.ToTable("taches");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Titre).HasMaxLength(250).IsRequired();
            entity.Property(x => x.Statut).HasMaxLength(80);
            entity.Property(x => x.Priorite).HasMaxLength(80);
        });

        modelBuilder.Entity<Utilisateur>(entity =>
        {
            entity.ToTable("utilisateurs");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Nom).HasMaxLength(150).IsRequired();
            entity.Property(x => x.Email).HasMaxLength(250).IsRequired();
            entity.Property(x => x.Role).HasMaxLength(80);
        });
    }
}


