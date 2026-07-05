#!/bin/bash
set -e

cd /opt/lexpilot-ovh

echo "=== Ajout packages EF Core PostgreSQL ==="
dotnet add src/LexPilot.Infrastructure/LexPilot.Infrastructure.csproj package Microsoft.EntityFrameworkCore --version 10.0.0
dotnet add src/LexPilot.Infrastructure/LexPilot.Infrastructure.csproj package Npgsql.EntityFrameworkCore.PostgreSQL --version 10.0.0
dotnet add src/LexPilot.Api/LexPilot.Api.csproj package Microsoft.EntityFrameworkCore.Design --version 10.0.0

echo "=== Création dossiers ==="
mkdir -p src/LexPilot.Domain/Clients
mkdir -p src/LexPilot.Infrastructure/Data
mkdir -p src/LexPilot.Api/Controllers

echo "=== Entité Client ==="
cat > src/LexPilot.Domain/Clients/Client.cs <<'CS'
namespace LexPilot.Domain.Clients;

public class Client
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string FirstName { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;

    public string? CompanyName { get; set; }

    public string? Email { get; set; }

    public string? Phone { get; set; }

    public string? Address { get; set; }

    public string? City { get; set; }

    public string? PostalCode { get; set; }

    public string? Notes { get; set; }

    public bool IsArchived { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public DateTime? UpdatedAtUtc { get; set; }
}
CS

echo "=== DbContext ==="
cat > src/LexPilot.Infrastructure/Data/AppDbContext.cs <<'CS'
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
CS

echo "=== DependencyInjection Infrastructure ==="
cat > src/LexPilot.Infrastructure/DependencyInjection.cs <<'CS'
using LexPilot.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace LexPilot.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection")));

        return services;
    }
}
CS

echo "=== appsettings ==="
cat > src/LexPilot.Api/appsettings.json <<'JSON'
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=lexpilot_db;Username=lexpilot;Password=lexpilot_password"
  },
  "AllowedHosts": "*"
}
JSON

echo "=== Controller Clients ==="
cat > src/LexPilot.Api/Controllers/ClientsController.cs <<'CS'
using LexPilot.Domain.Clients;
using LexPilot.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/clients")]
public class ClientsController : ControllerBase
{
    private readonly AppDbContext _db;

    public ClientsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Client>>> GetClients([FromQuery] string? search = null)
    {
        var query = _db.Clients
            .Where(x => !x.IsArchived)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var value = search.ToLower();
            query = query.Where(x =>
                x.FirstName.ToLower().Contains(value) ||
                x.LastName.ToLower().Contains(value) ||
                (x.CompanyName != null && x.CompanyName.ToLower().Contains(value)) ||
                (x.Email != null && x.Email.ToLower().Contains(value)));
        }

        var clients = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(100)
            .ToListAsync();

        return Ok(clients);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<Client>> GetClient(Guid id)
    {
        var client = await _db.Clients.FindAsync(id);

        if (client == null || client.IsArchived)
            return NotFound();

        return Ok(client);
    }

    [HttpPost]
    public async Task<ActionResult<Client>> CreateClient(Client client)
    {
        client.Id = Guid.NewGuid();
        client.CreatedAtUtc = DateTime.UtcNow;

        _db.Clients.Add(client);
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetClient), new { id = client.Id }, client);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> UpdateClient(Guid id, Client input)
    {
        var client = await _db.Clients.FindAsync(id);

        if (client == null || client.IsArchived)
            return NotFound();

        client.FirstName = input.FirstName;
        client.LastName = input.LastName;
        client.CompanyName = input.CompanyName;
        client.Email = input.Email;
        client.Phone = input.Phone;
        client.Address = input.Address;
        client.City = input.City;
        client.PostalCode = input.PostalCode;
        client.Notes = input.Notes;
        client.UpdatedAtUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        return NoContent();
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> ArchiveClient(Guid id)
    {
        var client = await _db.Clients.FindAsync(id);

        if (client == null)
            return NotFound();

        client.IsArchived = true;
        client.UpdatedAtUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        return NoContent();
    }
}
CS

echo "=== Program.cs avec EF migration auto ==="
cat > src/LexPilot.Api/Program.cs <<'CS'
using LexPilot.Infrastructure;
using LexPilot.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddControllers();
builder.Services.AddInfrastructure(builder.Configuration);

var app = builder.Build();

app.MapOpenApi();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
}

app.MapGet("/", () => Results.Ok(new
{
    app = "LexPilot OVH",
    status = "running",
    version = "0.2.0"
}));

app.MapGet("/health", () => Results.Ok(new
{
    status = "ok",
    app = "LexPilot.Api",
    version = "0.2.0"
}));

app.MapGet("/api/dashboard", async (AppDbContext db) => Results.Ok(new
{
    clients = await db.Clients.CountAsync(x => !x.IsArchived),
    dossiers = 0,
    documents = 0,
    message = "Sprint 2 Clients actif"
}));

app.MapControllers();

app.Run();
CS

echo "=== PostgreSQL ==="
docker compose up -d

echo "=== Build ==="
dotnet restore
dotnet build

echo "=== Restart API ==="
pkill -f "LexPilot.Api" || true
pkill -f "dotnet run --project src/LexPilot.Api" || true

nohup dotnet run --project src/LexPilot.Api/LexPilot.Api.csproj --urls http://0.0.0.0:5128 > lexpilot.log 2>&1 &

sleep 6

echo "=== Test health ==="
curl http://localhost:5128/health
echo ""

echo "=== Test création client ==="
curl -X POST http://localhost:5128/api/clients \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Jean","lastName":"Dupont","email":"jean.dupont@test.fr","phone":"0600000000","city":"Lille"}'
echo ""

echo "=== Liste clients ==="
curl http://localhost:5128/api/clients
echo ""

echo "=== Git commit ==="
git add .
git commit -m "Sprint 2 - Clients API with PostgreSQL" || true
git push || true

echo ""
echo "SPRINT 2 TERMINE"
