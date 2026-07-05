#!/bin/bash
set -e

cd /opt/lexpilot-ovh

mkdir -p src/LexPilot.Domain/Taches

cat > src/LexPilot.Domain/Taches/Tache.cs <<'CS'
namespace LexPilot.Domain.Taches;

public class Tache
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Titre { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string Statut { get; set; } = "A faire";
    public string Priorite { get; set; } = "Normale";
    public DateTime? DateEcheance { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public bool IsArchived { get; set; }
}
CS

python3 - <<'PY'
from pathlib import Path
p = Path("src/LexPilot.Infrastructure/Data/AppDbContext.cs")
s = p.read_text()

if "LexPilot.Domain.Taches" not in s:
    s = s.replace("using LexPilot.Domain.Documents;", "using LexPilot.Domain.Documents;\nusing LexPilot.Domain.Taches;")

if "DbSet<Tache>" not in s:
    s = s.replace("public DbSet<Document> Documents => Set<Document>();", "public DbSet<Document> Documents => Set<Document>();\n    public DbSet<Tache> Taches => Set<Tache>();")

if 'entity.ToTable("taches");' not in s:
    s = s.replace("    }\n}", '''
        modelBuilder.Entity<Tache>(entity =>
        {
            entity.ToTable("taches");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Titre).HasMaxLength(250).IsRequired();
            entity.Property(x => x.Statut).HasMaxLength(80);
            entity.Property(x => x.Priorite).HasMaxLength(80);
        });
    }
}
''')

p.write_text(s)
PY

cat > src/LexPilot.Api/Controllers/TachesController.cs <<'CS'
using LexPilot.Domain.Taches;
using LexPilot.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/taches")]
public class TachesController : ControllerBase
{
    private readonly AppDbContext _db;

    public TachesController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetTaches()
    {
        var taches = await _db.Taches
            .Where(x => !x.IsArchived)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(100)
            .ToListAsync();

        return Ok(taches);
    }

    [HttpPost]
    public async Task<IActionResult> CreateTache(Tache tache)
    {
        tache.Id = Guid.NewGuid();
        tache.CreatedAtUtc = DateTime.UtcNow;

        _db.Taches.Add(tache);
        await _db.SaveChangesAsync();

        return Ok(tache);
    }

    [HttpPut("{id:guid}/done")]
    public async Task<IActionResult> MarkDone(Guid id)
    {
        var tache = await _db.Taches.FindAsync(id);
        if (tache == null) return NotFound();

        tache.Statut = "Terminee";
        await _db.SaveChangesAsync();

        return NoContent();
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Archive(Guid id)
    {
        var tache = await _db.Taches.FindAsync(id);
        if (tache == null) return NotFound();

        tache.IsArchived = true;
        await _db.SaveChangesAsync();

        return NoContent();
    }
}
CS

python3 - <<'PY'
from pathlib import Path
p = Path("web/index.html")
s = p.read_text()

if "showTaches" not in s:
    s = s.replace(
        '<div onclick="showAgenda()">📅 Agenda</div>',
        '<div onclick="showAgenda()">📅 Agenda</div>\n    <div onclick="showTaches()">✅ Tâches</div>'
    )

    s = s.replace("showDashboard();", '''
async function showTaches(){
  const r = await fetch("/api/taches");
  const data = await r.json();
  let rows = data.map(x => `<tr><td>${x.titre}</td><td>${x.priorite}</td><td>${x.statut}</td></tr>`).join("");
  document.getElementById("app").innerHTML = `
    <h1>✅ Tâches</h1>
    <div class="card">
      <input id="taskTitle" placeholder="Nouvelle tâche">
      <button onclick="createTache()">Ajouter</button>
    </div>
    <br>
    <table><tr><th>Titre</th><th>Priorité</th><th>Statut</th></tr>${rows}</table>
  `;
}

async function createTache(){
  await fetch("/api/taches", {
    method:"POST",
    headers:{ "Content-Type":"application/json" },
    body: JSON.stringify({
      titre: document.getElementById("taskTitle").value,
      priorite: "Normale",
      statut: "A faire"
    })
  });
  showTaches();
}

showDashboard();''')

p.write_text(s)
PY

dotnet build

sudo systemctl restart lexpilot-api
sudo systemctl restart nginx

sleep 5

curl http://localhost/health
echo ""

curl -X POST http://localhost/api/taches \
  -H "Content-Type: application/json" \
  -d '{"titre":"Appeler client Dupont","description":"Préparer le dossier avant rendez-vous","priorite":"Haute"}'
echo ""

curl http://localhost/api/taches
echo ""

git add .
git commit -m "Add simple tasks module" || true
git push || true

echo "Module Taches ajoute. Recharge http://51.255.161.205 avec Ctrl+F5"
