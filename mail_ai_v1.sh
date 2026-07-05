#!/bin/bash
set -e

cd /opt/lexpilot-ovh

cat > src/LexPilot.Api/Controllers/MailAiController.cs <<'CS'
using LexPilot.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/mail-ai")]
public class MailAiController : ControllerBase
{
    private readonly AppDbContext _db;

    public MailAiController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet("inbox")]
    public IActionResult Inbox([FromQuery] string? search = null)
    {
        var mails = new[]
        {
            new { id = "m1", from = "jean.dupont@test.fr", subject = "Documents divorce", body = "Bonjour, voici les pièces pour mon divorce.", date = DateTime.UtcNow.AddHours(-1) },
            new { id = "m2", from = "sophie.martin@test.fr", subject = "Licenciement", body = "Je vous transmets mon contrat de travail et mon courrier de licenciement.", date = DateTime.UtcNow.AddHours(-3) },
            new { id = "m3", from = "greffe@justice.fr", subject = "Convocation audience TJ Lille", body = "Convocation pour audience civile.", date = DateTime.UtcNow.AddHours(-5) }
        };

        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.ToLower();
            mails = mails.Where(x =>
                x.from.ToLower().Contains(q) ||
                x.subject.ToLower().Contains(q) ||
                x.body.ToLower().Contains(q)).ToArray();
        }

        return Ok(mails);
    }

    [HttpGet("suggest-dossier")]
    public async Task<IActionResult> SuggestDossier([FromQuery] string text)
    {
        var dossiers = await _db.Dossiers
            .Include(x => x.Client)
            .Where(x => !x.IsArchived)
            .Take(100)
            .ToListAsync();

        var lower = text.ToLower();

        var best = dossiers
            .Select(d => new
            {
                d.Id,
                d.Numero,
                d.Titre,
                d.TypeAffaire,
                Score =
                    (lower.Contains(d.Numero.ToLower()) ? 10 : 0) +
                    (lower.Contains(d.Titre.ToLower()) ? 8 : 0) +
                    (lower.Contains(d.TypeAffaire.ToLower()) ? 4 : 0) +
                    (d.Client != null && lower.Contains(d.Client.LastName.ToLower()) ? 7 : 0) +
                    (d.Client != null && lower.Contains(d.Client.FirstName.ToLower()) ? 5 : 0)
            })
            .OrderByDescending(x => x.Score)
            .FirstOrDefault();

        return Ok(new
        {
            status = "ok",
            engine = "LexPilot IA locale V1",
            suggestion = best,
            message = best == null || best.Score == 0
                ? "Aucun dossier évident détecté."
                : $"Suggestion : {best.Numero} - {best.Titre}"
        });
    }

    [HttpPost("classify")]
    public IActionResult Classify([FromBody] ClassifyMailRequest request)
    {
        return Ok(new
        {
            status = "classified",
            mailId = request.MailId,
            dossierId = request.DossierId,
            message = "Mail classé virtuellement dans le dossier. Stockage réel prévu V2."
        });
    }
}

public record ClassifyMailRequest(string MailId, Guid DossierId);
CS

python3 - <<'PY'
from pathlib import Path
p = Path("web/index.html")
s = p.read_text()

mail_js = r'''
async function showMail(){
 const r = await fetch("/api/mail-ai/inbox");
 const mails = await r.json();
 let rows = "";
 for (const m of mails) {
   rows += `<tr>
     <td>${m.from}</td>
     <td>${m.subject}</td>
     <td><button onclick="suggestMail('${m.id}', '${(m.subject + " " + m.body).replaceAll("'"," ")}')">IA dossier</button></td>
   </tr>`;
 }
 app.innerHTML = `<h1>📧 Mail intelligent</h1>
 <div class="card">
   <input id="mailSearch" placeholder="Rechercher mail, expéditeur, sujet...">
   <button onclick="searchMail()">Rechercher</button>
 </div>
 <table><tr><th>Expéditeur</th><th>Sujet</th><th>Action</th></tr>${rows}</table>
 <div id="mailResult" class="card"></div>`;
}

async function searchMail(){
 const q = document.getElementById("mailSearch").value;
 const r = await fetch("/api/mail-ai/inbox?search=" + encodeURIComponent(q));
 const mails = await r.json();
 let rows = mails.map(m => `<tr><td>${m.from}</td><td>${m.subject}</td><td><button onclick="suggestMail('${m.id}', '${(m.subject + " " + m.body).replaceAll("'"," ")}')">IA dossier</button></td></tr>`).join("");
 app.innerHTML = `<h1>📧 Résultat recherche mail</h1><button onclick="showMail()">Retour</button><table><tr><th>Expéditeur</th><th>Sujet</th><th>Action</th></tr>${rows}</table><div id="mailResult" class="card"></div>`;
}

async function suggestMail(mailId, text){
 const r = await fetch("/api/mail-ai/suggest-dossier?text=" + encodeURIComponent(text));
 const d = await r.json();
 if (!d.suggestion || d.suggestion.score === 0) {
   document.getElementById("mailResult").innerHTML = `<b>IA :</b> ${d.message}`;
   return;
 }
 document.getElementById("mailResult").innerHTML =
   `<h3>Suggestion IA</h3>
    <p>${d.message}</p>
    <button onclick="classifyMail('${mailId}', '${d.suggestion.id}')">Classer dans ce dossier</button>`;
}

async function classifyMail(mailId, dossierId){
 const r = await fetch("/api/mail-ai/classify", {
   method:"POST",
   headers:{ "Content-Type":"application/json" },
   body: JSON.stringify({ mailId, dossierId })
 });
 const d = await r.json();
 document.getElementById("mailResult").innerHTML = `<b>${d.status}</b> : ${d.message}`;
}
'''

# remplace l'ancienne fonction showMail
start = s.find("function showMail()")
if start != -1:
    end = s.find("function showOffice365()", start)
    s = s[:start] + mail_js + "\n" + s[end:]
else:
    s = s.replace("showDashboard();", mail_js + "\nshowDashboard();")

p.write_text(s)
PY

dotnet build

sudo systemctl restart lexpilot-api
sudo systemctl restart nginx

sleep 5

curl http://localhost/api/mail-ai/inbox
echo ""
curl "http://localhost/api/mail-ai/suggest-dossier?text=Documents%20divorce%20Dupont"
echo ""

git add .
git commit -m "Add intelligent mail search and dossier classification IA V1" || true
git push || true

echo "OK : recharge http://51.255.161.205 avec Ctrl+F5 puis ouvre Mail"
