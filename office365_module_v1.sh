#!/bin/bash
set -e

cd /opt/lexpilot-ovh

cat > src/LexPilot.Api/Controllers/Office365Controller.cs <<'CS'
using Microsoft.AspNetCore.Mvc;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/office365")]
public class Office365Controller : ControllerBase
{
    [HttpGet("status")]
    public IActionResult Status()
    {
        var tenantId = Environment.GetEnvironmentVariable("OUTLOOK_TENANT_ID");
        var clientId = Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_ID");
        var clientSecret = Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_SECRET");

        var configured =
            !string.IsNullOrWhiteSpace(tenantId) &&
            !string.IsNullOrWhiteSpace(clientId) &&
            !string.IsNullOrWhiteSpace(clientSecret);

        return Ok(new
        {
            service = "Microsoft 365 / Outlook",
            configured,
            status = configured ? "ready" : "missing_configuration",
            features = new[]
            {
                "Lecture des emails",
                "Envoi de mails",
                "Pièces jointes",
                "Classement dans les dossiers",
                "Synchronisation agenda",
                "Résumé IA des échanges"
            }
        });
    }

    [HttpGet("inbox-preview")]
    public IActionResult InboxPreview()
    {
        return Ok(new[]
        {
            new { from = "client@example.com", subject = "Transmission des pièces", dossier = "À classer", date = DateTime.UtcNow },
            new { from = "tribunal@example.com", subject = "Convocation audience", dossier = "À détecter", date = DateTime.UtcNow.AddHours(-2) },
            new { from = "confrere@example.com", subject = "Conclusions adverses", dossier = "À rattacher", date = DateTime.UtcNow.AddHours(-5) }
        });
    }
}
CS

python3 - <<'PY'
from pathlib import Path
p = Path("web/index.html")
s = p.read_text()

marker = "function showOffice365(){"
start = s.find(marker)
if start != -1:
    end = s.find("function ", start + len(marker))
    if end == -1:
        end = s.find("showDashboard();", start)
    replacement = r'''
async function showOffice365(){
  const r = await fetch("/api/office365/status");
  const status = await r.json();

  const inboxR = await fetch("/api/office365/inbox-preview");
  const mails = await inboxR.json();

  let mailRows = mails.map(x => `<tr><td>${x.from}</td><td>${x.subject}</td><td>${x.dossier}</td></tr>`).join("");

  document.getElementById("app").innerHTML = `
    <h1>📨 Office 365 / Outlook</h1>

    <div class="cards">
      <div class="card"><h2>${status.configured ? "OK" : "À configurer"}</h2><p>Connexion Microsoft Graph</p></div>
      <div class="card"><h2>3</h2><p>Mails exemple</p></div>
      <div class="card"><h2>0</h2><p>Mails classés</p></div>
    </div>

    <div class="card">
      <h3>Fonctions prévues</h3>
      <p>${status.features.join(" • ")}</p>
    </div>

    <div class="card">
      <h3>Boîte de réception - aperçu</h3>
      <table>
        <tr><th>Expéditeur</th><th>Sujet</th><th>Dossier</th></tr>
        ${mailRows}
      </table>
    </div>

    <div class="card">
      <h3>Configuration requise</h3>
      <p>Créer une application dans Microsoft Entra ID, puis renseigner Tenant ID, Client ID et Client Secret sur le serveur.</p>
    </div>
  `;
}

'''
    s = s[:start] + replacement + s[end:]

p.write_text(s)
PY

dotnet build

sudo systemctl restart lexpilot-api
sudo systemctl restart nginx

sleep 5

curl http://localhost/api/office365/status
echo ""
curl http://localhost/api/office365/inbox-preview
echo ""

git add .
git commit -m "Add Office 365 module status and inbox preview" || true
git push || true

echo "OK : recharge http://51.255.161.205 avec Ctrl+F5 puis ouvre Office 365 / Outlook"
