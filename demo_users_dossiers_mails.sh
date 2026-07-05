#!/bin/bash
set -e

cd /opt/lexpilot-ovh

echo "=== Vérification API ==="
curl http://localhost/health
echo ""

echo "=== Création utilisateurs ==="
curl -X POST http://localhost/api/utilisateurs -H "Content-Type: application/json" \
  -d '{"nom":"Jérémy Admin","email":"admin@lexpilot.local","role":"Administrateur","actif":true}'
echo ""

curl -X POST http://localhost/api/utilisateurs -H "Content-Type: application/json" \
  -d '{"nom":"Maître Martin","email":"avocat@cabinet.fr","role":"Avocat","actif":true}'
echo ""

curl -X POST http://localhost/api/utilisateurs -H "Content-Type: application/json" \
  -d '{"nom":"Assistante Cabinet","email":"assistant@cabinet.fr","role":"Assistant","actif":true}'
echo ""

echo "=== Création clients ==="
CLIENT1=$(curl -s -X POST http://localhost/api/clients -H "Content-Type: application/json" \
  -d '{"firstName":"Jean","lastName":"Dupont","email":"jean.dupont@test.fr","phone":"0600000000","city":"Lille"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

CLIENT2=$(curl -s -X POST http://localhost/api/clients -H "Content-Type: application/json" \
  -d '{"firstName":"Sophie","lastName":"Martin","email":"sophie.martin@test.fr","phone":"0611111111","city":"Roubaix"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

CLIENT3=$(curl -s -X POST http://localhost/api/clients -H "Content-Type: application/json" \
  -d '{"firstName":"Karim","lastName":"Benali","email":"karim.benali@test.fr","phone":"0622222222","city":"Tourcoing"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

echo "=== Création dossiers ==="
curl -X POST http://localhost/api/dossiers -H "Content-Type: application/json" \
  -d "{\"numero\":\"D-2026-0001\",\"titre\":\"Divorce amiable Dupont\",\"typeAffaire\":\"Famille\",\"statut\":\"Ouvert\",\"juridiction\":\"TJ Lille\",\"clientId\":\"$CLIENT1\"}"
echo ""

curl -X POST http://localhost/api/dossiers -H "Content-Type: application/json" \
  -d "{\"numero\":\"D-2026-0002\",\"titre\":\"Licenciement contesté Martin\",\"typeAffaire\":\"Droit du travail\",\"statut\":\"En cours\",\"juridiction\":\"Conseil de prud'hommes Lille\",\"clientId\":\"$CLIENT2\"}"
echo ""

curl -X POST http://localhost/api/dossiers -H "Content-Type: application/json" \
  -d "{\"numero\":\"D-2026-0003\",\"titre\":\"Litige commercial Benali\",\"typeAffaire\":\"Commercial\",\"statut\":\"Ouvert\",\"juridiction\":\"Tribunal de commerce Lille\",\"clientId\":\"$CLIENT3\"}"
echo ""

echo "=== Mise à jour interface Office 365 avec mails exemples ==="
python3 - <<'PY'
from pathlib import Path
p = Path("web/index.html")
s = p.read_text()

extra = '''
function showMailDemo(){
  document.getElementById("app").innerHTML = `
    <h1>📧 Mails à classer</h1>
    <div class="card">
      <h3>Boîte Office 365 - exemples</h3>
      <table>
        <tr><th>Expéditeur</th><th>Sujet</th><th>Suggestion dossier</th><th>Action</th></tr>
        <tr><td>jean.dupont@test.fr</td><td>Documents divorce</td><td>D-2026-0001</td><td><button>Classer</button></td></tr>
        <tr><td>sophie.martin@test.fr</td><td>Contrat de travail</td><td>D-2026-0002</td><td><button>Classer</button></td></tr>
        <tr><td>greffe@justice.fr</td><td>Convocation audience</td><td>D-2026-0003</td><td><button>Classer</button></td></tr>
      </table>
    </div>
  `;
}
'''

if "showMailDemo" not in s:
    s = s.replace('<div onclick="showMail()">📧 Mail</div>', '<div onclick="showMail()">📧 Mail</div>\\n    <div onclick="showMailDemo()">📥 Mails à classer</div>')
    s = s.replace("showDashboard();", extra + "\\nshowDashboard();")

p.write_text(s)
PY

sudo systemctl restart nginx

echo "=== Tests ==="
curl http://localhost/api/utilisateurs
echo ""
curl http://localhost/api/clients
echo ""
curl http://localhost/api/dossiers
echo ""
curl http://localhost/api/dashboard
echo ""

git add .
git commit -m "Add demo users dossiers and mail classification examples" || true
git push || true

echo "OK : recharge http://51.255.161.205 avec Ctrl+F5"
