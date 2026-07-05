#!/bin/bash
set -e

cd /opt/lexpilot-ovh

python3 - <<'PY'
from pathlib import Path
p = Path("web/index.html")
s = p.read_text()

s = s.replace(
'''    <div onclick="showMail()">📧 Mail</div>''',
'''    <div onclick="showMail()">📧 Mail</div>
    <div onclick="showOffice365()">📨 Office 365 / Outlook</div>'''
)

s = s.replace(
'''function showMail(){ document.getElementById("app").innerHTML = "<h1>📧 Mail</h1><div class='card'>Module messagerie : réception, classement par dossier, pièces jointes, suivi des échanges.</div>"; }''',
'''function showMail(){ document.getElementById("app").innerHTML = "<h1>📧 Mail</h1><div class='card'>Module messagerie : réception, classement par dossier, pièces jointes, suivi des échanges.</div>"; }

function showOffice365(){
  document.getElementById("app").innerHTML = `
    <h1>📨 Office 365 / Outlook</h1>
    <div class="cards">
      <div class="card"><h2>0</h2><p>Mails reçus</p></div>
      <div class="card"><h2>0</h2><p>Mails à classer</p></div>
      <div class="card"><h2>0</h2><p>Pièces jointes</p></div>
    </div>
    <div class="card">
      <h3>Connexion Microsoft 365</h3>
      <p>Prévu : connexion via Microsoft Graph avec OAuth sécurisé.</p>
      <button>Connecter Office 365</button>
    </div>
    <div class="card">
      <h3>Fonctions prévues</h3>
      <p>Lecture des emails, envoi, pièces jointes, classement automatique dans les dossiers, résumé IA des échanges.</p>
    </div>
    <div class="card">
      <h3>Classement intelligent</h3>
      <p>LexPilot pourra associer un email à un client ou à un dossier selon l'expéditeur, le sujet, les pièces jointes et le contenu.</p>
    </div>
  `;
}'''
)

p.write_text(s)
PY

sudo systemctl restart nginx

git add .
git commit -m "Add Office 365 Outlook mail module placeholder" || true
git push || true

echo "OK : recharge http://51.255.161.205 avec Ctrl+F5"
