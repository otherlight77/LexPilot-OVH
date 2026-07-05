#!/bin/bash
set -e

cd /opt/lexpilot-ovh

mkdir -p src/LexPilot.Api/Controllers

cat > src/LexPilot.Api/Controllers/V1ModulesController.cs <<'CS'
using Microsoft.AspNetCore.Mvc;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/v1")]
public class V1ModulesController : ControllerBase
{
    [HttpGet("modules")]
    public IActionResult Modules() => Ok(new
    {
        version = "V1",
        modules = new[]
        {
            "Agenda", "Facturation", "Portail client", "Signature électronique",
            "Téléphonie", "IA", "OCR", "Légifrance", "Marketing SEO", "Office 365"
        }
    });

    [HttpGet("agenda")]
    public IActionResult Agenda() => Ok(new[]
    {
        new { date = "Aujourd'hui", titre = "Rendez-vous client Dupont", type = "RDV" },
        new { date = "Demain", titre = "Audience TJ Lille", type = "Audience" }
    });

    [HttpGet("facturation")]
    public IActionResult Facturation() => Ok(new { caMois = 0, factures = 0, honorairesAttente = 0 });

    [HttpGet("portal")]
    public IActionResult Portal() => Ok(new { clientsConnectes = 0, documentsDeposes = 0, signaturesEnAttente = 0 });

    [HttpGet("ia")]
    public IActionResult Ia() => Ok(new { analyses = 0, resumes = 0, documentsAnalyse = 0, status = "pret" });

    [HttpGet("marketing")]
    public IActionResult Marketing() => Ok(new { visiteurs = 0, prospects = 0, seo = "a connecter" });

    [HttpGet("signature")]
    public IActionResult Signature() => Ok(new { provider = "Yousign / DocuSign / Universign", status = "a configurer" });

    [HttpGet("telephonie")]
    public IActionResult Telephonie() => Ok(new { appels = 0, provider = "Teams / OVH / Aircall / 3CX", status = "a configurer" });
}
CS

python3 - <<'PY'
from pathlib import Path
p = Path("web/index.html")
s = p.read_text()

menu_items = '''
    <div onclick="showAgendaV1()">📅 Agenda V1</div>
    <div onclick="showBilling()">💰 Facturation</div>
    <div onclick="showPortal()">👤 Portail client</div>
    <div onclick="showSignature()">✍️ Signature</div>
    <div onclick="showPhone()">📞 Téléphonie</div>
    <div onclick="showAiV1()">🤖 IA V1</div>
'''

if "showBilling()" not in s:
    s = s.replace("<div>⚙️ Paramètres</div>", menu_items + "\n    <div>⚙️ Paramètres</div>")

js = r'''
async function showAgendaV1(){
  const r = await fetch("/api/v1/agenda");
  const data = await r.json();
  let rows = data.map(x => `<tr><td>${x.date}</td><td>${x.titre}</td><td>${x.type}</td></tr>`).join("");
  document.getElementById("app").innerHTML = `<h1>📅 Agenda V1</h1><table><tr><th>Date</th><th>Titre</th><th>Type</th></tr>${rows}</table>`;
}

async function showBilling(){
  const r = await fetch("/api/v1/facturation");
  const d = await r.json();
  document.getElementById("app").innerHTML = `<h1>💰 Facturation</h1><div class="cards"><div class="card"><h2>${d.caMois} €</h2><p>CA du mois</p></div><div class="card"><h2>${d.factures}</h2><p>Factures</p></div><div class="card"><h2>${d.honorairesAttente} €</h2><p>Honoraires attente</p></div></div>`;
}

async function showPortal(){
  const r = await fetch("/api/v1/portal");
  const d = await r.json();
  document.getElementById("app").innerHTML = `<h1>👤 Portail client</h1><div class="card">Clients connectés : ${d.clientsConnectes}<br>Documents déposés : ${d.documentsDeposes}<br>Signatures en attente : ${d.signaturesEnAttente}</div>`;
}

async function showSignature(){
  const r = await fetch("/api/v1/signature");
  const d = await r.json();
  document.getElementById("app").innerHTML = `<h1>✍️ Signature électronique</h1><div class="card"><b>Fournisseurs :</b> ${d.provider}<br><b>Statut :</b> ${d.status}</div>`;
}

async function showPhone(){
  const r = await fetch("/api/v1/telephonie");
  const d = await r.json();
  document.getElementById("app").innerHTML = `<h1>📞 Téléphonie</h1><div class="card"><b>Appels :</b> ${d.appels}<br><b>Connecteurs :</b> ${d.provider}<br><b>Statut :</b> ${d.status}</div>`;
}

async function showAiV1(){
  const r = await fetch("/api/v1/ia");
  const d = await r.json();
  document.getElementById("app").innerHTML = `<h1>🤖 IA V1</h1><div class="cards"><div class="card"><h2>${d.analyses}</h2><p>Analyses</p></div><div class="card"><h2>${d.resumes}</h2><p>Résumés</p></div><div class="card"><h2>${d.documentsAnalyse}</h2><p>Documents analysés</p></div></div><div class="card">Statut : ${d.status}</div>`;
}
'''

if "function showBilling()" not in s:
    s = s.replace("showDashboard();", js + "\nshowDashboard();")

p.write_text(s)
PY

dotnet build

sudo systemctl restart lexpilot-api
sudo systemctl restart nginx

sleep 5

curl http://localhost/api/v1/modules
echo ""

git add .
git commit -m "Add V1 visible modules agenda billing portal signature phone IA" || true
git push || true

echo "OK : recharge http://51.255.161.205 avec Ctrl+F5"
