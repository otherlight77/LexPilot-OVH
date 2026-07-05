#!/bin/bash
set -e

cd /opt/lexpilot-ovh

mkdir -p src/LexPilot.Domain/Utilisateurs

cat > src/LexPilot.Domain/Utilisateurs/Utilisateur.cs <<'CS'
namespace LexPilot.Domain.Utilisateurs;

public class Utilisateur
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Nom { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Role { get; set; } = "Utilisateur";
    public bool Actif { get; set; } = true;
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
CS

python3 - <<'PY'
from pathlib import Path
p = Path("src/LexPilot.Infrastructure/Data/AppDbContext.cs")
s = p.read_text()

if "LexPilot.Domain.Utilisateurs" not in s:
    s = s.replace("using LexPilot.Domain.Taches;", "using LexPilot.Domain.Taches;\nusing LexPilot.Domain.Utilisateurs;")

if "DbSet<Utilisateur>" not in s:
    s = s.replace("public DbSet<Tache> Taches => Set<Tache>();", "public DbSet<Tache> Taches => Set<Tache>();\n    public DbSet<Utilisateur> Utilisateurs => Set<Utilisateur>();")

if 'entity.ToTable("utilisateurs");' not in s:
    s = s.replace("    }\n}", '''
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
''')

p.write_text(s)
PY

cat > src/LexPilot.Api/Controllers/UtilisateursController.cs <<'CS'
using LexPilot.Domain.Utilisateurs;
using LexPilot.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/utilisateurs")]
public class UtilisateursController : ControllerBase
{
    private readonly AppDbContext _db;

    public UtilisateursController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> Get()
    {
        var users = await _db.Utilisateurs
            .OrderByDescending(x => x.CreatedAtUtc)
            .ToListAsync();

        return Ok(users);
    }

    [HttpPost]
    public async Task<IActionResult> Create(Utilisateur user)
    {
        user.Id = Guid.NewGuid();
        user.CreatedAtUtc = DateTime.UtcNow;
        _db.Utilisateurs.Add(user);
        await _db.SaveChangesAsync();
        return Ok(user);
    }
}
CS

cat > src/LexPilot.Api/Controllers/LegifranceController.cs <<'CS'
using Microsoft.AspNetCore.Mvc;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/legifrance")]
public class LegifranceController : ControllerBase
{
    [HttpGet("test")]
    public IActionResult Test()
    {
        var clientId = Environment.GetEnvironmentVariable("LEGIFRANCE_CLIENT_ID");
        var clientSecret = Environment.GetEnvironmentVariable("LEGIFRANCE_CLIENT_SECRET");

        if (string.IsNullOrWhiteSpace(clientId) || string.IsNullOrWhiteSpace(clientSecret))
        {
            return Ok(new
            {
                status = "configuration_missing",
                service = "Legifrance / PISTE",
                message = "Identifiants API Légifrance non configurés. Le module est prêt côté LexPilot."
            });
        }

        return Ok(new
        {
            status = "configured",
            service = "Legifrance / PISTE",
            message = "Identifiants détectés. Prochaine étape : appel OAuth + recherche juridique."
        });
    }
}
CS

cat > src/LexPilot.Api/Controllers/OutlookController.cs <<'CS'
using Microsoft.AspNetCore.Mvc;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/outlook")]
public class OutlookController : ControllerBase
{
    [HttpGet("test")]
    public IActionResult Test()
    {
        var tenant = Environment.GetEnvironmentVariable("OUTLOOK_TENANT_ID");
        var clientId = Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_ID");
        var clientSecret = Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_SECRET");

        if (string.IsNullOrWhiteSpace(tenant) || string.IsNullOrWhiteSpace(clientId) || string.IsNullOrWhiteSpace(clientSecret))
        {
            return Ok(new
            {
                status = "configuration_missing",
                service = "Microsoft Graph / Outlook",
                message = "Identifiants Microsoft 365 non configurés. Le module est prêt côté LexPilot."
            });
        }

        return Ok(new
        {
            status = "configured",
            service = "Microsoft Graph / Outlook",
            message = "Identifiants détectés. Prochaine étape : OAuth + lecture emails."
        });
    }
}
CS

python3 - <<'PY'
from pathlib import Path
p = Path("src/LexPilot.Api/Program.cs")
s = p.read_text()

if "CREATE TABLE IF NOT EXISTS utilisateurs" not in s:
    s = s.replace("db.Database.EnsureCreated();", '''
    db.Database.EnsureCreated();

    db.Database.ExecuteSqlRaw(@"
        CREATE TABLE IF NOT EXISTS utilisateurs (
            \"Id\" uuid PRIMARY KEY,
            \"Nom\" character varying(150) NOT NULL,
            \"Email\" character varying(250) NOT NULL,
            \"Role\" character varying(80) NOT NULL,
            \"Actif\" boolean NOT NULL,
            \"CreatedAtUtc\" timestamp with time zone NOT NULL
        );
    ");
''')

s = s.replace('version = "0.4.0"', 'version = "0.5.0"')
p.write_text(s)
PY

python3 - <<'PY'
from pathlib import Path
p = Path("web/index.html")
s = p.read_text()

if "showUsers" not in s:
    s = s.replace(
        '<div>⚙️ Paramètres</div>',
        '<div onclick="showUsers()">👤 Utilisateurs</div>\n    <div>⚙️ Paramètres</div>'
    )

    s = s.replace("showDashboard();", '''
async function showUsers(){
  const r = await fetch("/api/utilisateurs");
  const data = await r.json();
  let rows = data.map(x => `<tr><td>${x.nom}</td><td>${x.email}</td><td>${x.role}</td><td>${x.actif}</td></tr>`).join("");
  document.getElementById("app").innerHTML = `
    <h1>👤 Utilisateurs</h1>
    <div class="card">
      <input id="userNom" placeholder="Nom">
      <input id="userEmail" placeholder="Email">
      <input id="userRole" placeholder="Rôle" value="Avocat">
      <button onclick="createUser()">Ajouter</button>
    </div>
    <br>
    <table><tr><th>Nom</th><th>Email</th><th>Rôle</th><th>Actif</th></tr>${rows}</table>
  `;
}

async function createUser(){
  await fetch("/api/utilisateurs", {
    method:"POST",
    headers:{ "Content-Type":"application/json" },
    body: JSON.stringify({
      nom: document.getElementById("userNom").value,
      email: document.getElementById("userEmail").value,
      role: document.getElementById("userRole").value,
      actif: true
    })
  });
  showUsers();
}

async function testLegifranceLive(){
  const r = await fetch("/api/legifrance/test");
  const d = await r.json();
  alert(d.service + "\\n" + d.status + "\\n" + d.message);
}

async function testOutlookLive(){
  const r = await fetch("/api/outlook/test");
  const d = await r.json();
  alert(d.service + "\\n" + d.status + "\\n" + d.message);
}

function showLegifrance(){
  document.getElementById("app").innerHTML = `
    <h1>📚 Légifrance</h1>
    <div class="card"><p>Recherche juridique via API officielle Légifrance / PISTE.</p><button onclick="testLegifranceLive()">Tester connexion Légifrance</button></div>
  `;
}

function showOffice365(){
  document.getElementById("app").innerHTML = `
    <h1>📨 Office 365 / Outlook</h1>
    <div class="card"><p>Connexion future Microsoft Graph pour lire et classer les emails.</p><button onclick="testOutlookLive()">Tester connexion Outlook</button></div>
  `;
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

curl -X POST http://localhost/api/utilisateurs \
  -H "Content-Type: application/json" \
  -d '{"nom":"Administrateur LexPilot","email":"admin@lexpilot.local","role":"Administrateur","actif":true}'
echo ""

curl http://localhost/api/utilisateurs
echo ""

curl http://localhost/api/legifrance/test
echo ""

curl http://localhost/api/outlook/test
echo ""

git add .
git commit -m "Add users Legifrance and Outlook test modules" || true
git push || true

echo "OK : recharge http://51.255.161.205 avec Ctrl+F5"
