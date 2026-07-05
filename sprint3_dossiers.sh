#!/bin/bash
set -e

cd /opt/lexpilot-ovh

mkdir -p src/LexPilot.Domain/Dossiers

cat > src/LexPilot.Domain/Dossiers/Dossier.cs <<'CS'
using LexPilot.Domain.Clients;

namespace LexPilot.Domain.Dossiers;

public class Dossier
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Numero { get; set; } = string.Empty;
    public string Titre { get; set; } = string.Empty;
    public string TypeAffaire { get; set; } = string.Empty;
    public string Statut { get; set; } = "Ouvert";
    public string? Juridiction { get; set; }
    public string? Notes { get; set; }
    public Guid ClientId { get; set; }
    public Client? Client { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAtUtc { get; set; }
    public bool IsArchived { get; set; }
}
CS

python3 - <<'PY'
from pathlib import Path
p=Path("src/LexPilot.Infrastructure/Data/AppDbContext.cs")
s=p.read_text()
s=s.replace("using LexPilot.Domain.Clients;", "using LexPilot.Domain.Clients;\nusing LexPilot.Domain.Dossiers;")
s=s.replace("public DbSet<Client> Clients => Set<Client>();", "public DbSet<Client> Clients => Set<Client>();\n    public DbSet<Dossier> Dossiers => Set<Dossier>();")
insert='''
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
'''
s=s.replace("    }\n}", insert + "\n    }\n}")
p.write_text(s)
PY

cat > src/LexPilot.Api/Controllers/DossiersController.cs <<'CS'
using LexPilot.Domain.Dossiers;
using LexPilot.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/dossiers")]
public class DossiersController : ControllerBase
{
    private readonly AppDbContext _db;

    public DossiersController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetDossiers([FromQuery] string? search = null)
    {
        var query = _db.Dossiers.Include(x => x.Client).Where(x => !x.IsArchived);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var value = search.ToLower();
            query = query.Where(x =>
                x.Numero.ToLower().Contains(value) ||
                x.Titre.ToLower().Contains(value) ||
                x.TypeAffaire.ToLower().Contains(value) ||
                (x.Client != null && (
                    x.Client.FirstName.ToLower().Contains(value) ||
                    x.Client.LastName.ToLower().Contains(value)
                )));
        }

        var dossiers = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(100)
            .Select(x => new
            {
                x.Id,
                x.Numero,
                x.Titre,
                x.TypeAffaire,
                x.Statut,
                x.Juridiction,
                x.ClientId,
                Client = x.Client == null ? null : new { x.Client.Id, x.Client.FirstName, x.Client.LastName, x.Client.Email },
                x.CreatedAtUtc
            })
            .ToListAsync();

        return Ok(dossiers);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetDossier(Guid id)
    {
        var dossier = await _db.Dossiers.Include(x => x.Client).FirstOrDefaultAsync(x => x.Id == id && !x.IsArchived);
        return dossier == null ? NotFound() : Ok(dossier);
    }

    [HttpPost]
    public async Task<IActionResult> CreateDossier(Dossier dossier)
    {
        var clientExists = await _db.Clients.AnyAsync(x => x.Id == dossier.ClientId && !x.IsArchived);
        if (!clientExists) return BadRequest("Client introuvable.");

        dossier.Id = Guid.NewGuid();
        dossier.CreatedAtUtc = DateTime.UtcNow;

        _db.Dossiers.Add(dossier);
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetDossier), new { id = dossier.Id }, dossier);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> UpdateDossier(Guid id, Dossier input)
    {
        var dossier = await _db.Dossiers.FindAsync(id);
        if (dossier == null || dossier.IsArchived) return NotFound();

        dossier.Numero = input.Numero;
        dossier.Titre = input.Titre;
        dossier.TypeAffaire = input.TypeAffaire;
        dossier.Statut = input.Statut;
        dossier.Juridiction = input.Juridiction;
        dossier.Notes = input.Notes;
        dossier.UpdatedAtUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> ArchiveDossier(Guid id)
    {
        var dossier = await _db.Dossiers.FindAsync(id);
        if (dossier == null) return NotFound();

        dossier.IsArchived = true;
        dossier.UpdatedAtUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return NoContent();
    }
}
CS

python3 - <<'PY'
from pathlib import Path
p=Path("src/LexPilot.Api/Program.cs")
s=p.read_text()
s=s.replace("clients = await db.Clients.CountAsync(x => !x.IsArchived),\n    dossiers = 0,", "clients = await db.Clients.CountAsync(x => !x.IsArchived),\n    dossiers = await db.Dossiers.CountAsync(x => !x.IsArchived),")
s=s.replace('message = "Sprint 2 Clients actif"', 'message = "Sprint 3 Dossiers actif"')
s=s.replace('version = "0.2.0"', 'version = "0.3.0"')
p.write_text(s)
PY

dotnet build

pkill -f "LexPilot.Api" || true
nohup dotnet run --project src/LexPilot.Api/LexPilot.Api.csproj --urls http://0.0.0.0:5128 > lexpilot.log 2>&1 &

sleep 7

echo "HEALTH:"
curl http://localhost:5128/health
echo ""

echo "CLIENTS:"
CLIENT_ID=$(curl -s http://localhost:5128/api/clients | python3 -c "import sys,json; data=json.load(sys.stdin); print(data[0]['id'] if data else '')")

if [ -z "$CLIENT_ID" ]; then
  CLIENT_ID=$(curl -s -X POST http://localhost:5128/api/clients \
    -H "Content-Type: application/json" \
    -d '{"firstName":"Jean","lastName":"Dupont","email":"jean.dupont@test.fr","phone":"0600000000","city":"Lille"}' \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
fi

echo "ClientId=$CLIENT_ID"

echo "CREATION DOSSIER:"
curl -X POST http://localhost:5128/api/dossiers \
  -H "Content-Type: application/json" \
  -d "{\"numero\":\"D-2026-0001\",\"titre\":\"Premier dossier test\",\"typeAffaire\":\"Civil\",\"statut\":\"Ouvert\",\"juridiction\":\"Tribunal judiciaire de Lille\",\"clientId\":\"$CLIENT_ID\"}"
echo ""

echo "LISTE DOSSIERS:"
curl http://localhost:5128/api/dossiers
echo ""

echo "DASHBOARD:"
curl http://localhost:5128/api/dashboard
echo ""

git add .
git commit -m "Sprint 3 - Dossiers API linked to clients" || true
git push || true

echo "SPRINT 3 TERMINE"
