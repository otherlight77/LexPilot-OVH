#!/bin/bash
set -e

python3 - <<'PY'
from pathlib import Path

p = Path("web/index.html")
s = p.read_text()

# Ajoute les boutons si absents
if 'showMailDemo()' not in s:
    s = s.replace(
        '<div onclick="showMail()">📧 Mail</div>',
        '<div onclick="showMail()">📧 Mail</div>\n    <div onclick="showMailDemo()">📥 Mails à classer</div>'
    )

# Ajoute / remplace les fonctions mail
insert = r'''
function showMail(){
  document.getElementById("app").innerHTML = `
    <h1>📧 Mail</h1>
    <div class="card">
      <h3>Messagerie LexPilot</h3>
      <p>Réception, classement par dossier, pièces jointes, suivi des échanges.</p>
      <button onclick="showMailDemo()">Voir les mails à classer</button>
    </div>
  `;
}

function showMailDemo(){
  document.getElementById("app").innerHTML = `
    <h1>📥 Mails à classer</h1>
    <div class="card">
      <table>
        <tr><th>Expéditeur</th><th>Sujet</th><th>Dossier suggéré</th><th>Action</th></tr>
        <tr><td>jean.dupont@test.fr</td><td>Documents divorce</td><td>D-2026-0001</td><td><button>Classer</button></td></tr>
        <tr><td>sophie.martin@test.fr</td><td>Contrat de travail</td><td>D-2026-0002</td><td><button>Classer</button></td></tr>
        <tr><td>greffe@justice.fr</td><td>Convocation audience</td><td>D-2026-0003</td><td><button>Classer</button></td></tr>
      </table>
    </div>
  `;
}
'''

# Place les fonctions avant showDashboard
if "function showMailDemo()" not in s:
    s = s.replace("showDashboard();", insert + "\nshowDashboard();")

p.write_text(s)
PY

sudo systemctl restart nginx

git add .
git commit -m "Fix mail pages interface" || true
git push || true

echo "OK - recharge avec Ctrl+F5 : http://51.255.161.205"
