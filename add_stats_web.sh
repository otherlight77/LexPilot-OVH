#!/bin/bash
set -e

cd /opt/lexpilot-ovh

python3 - <<'PY'
from pathlib import Path
p = Path("web/index.html")
s = p.read_text()

s = s.replace(
'''    <div onclick="showVeille()">📚 Dernières lois</div>''',
'''    <div onclick="showVeille()">📚 Dernières lois</div>
    <div onclick="showStats()">📊 Statistiques Web / SEO</div>'''
)

s = s.replace(
'''function showVeille(){ document.getElementById("app").innerHTML = "<h1>📚 Dernières lois</h1><div class='card'>Module veille juridique : connexion future à Légifrance/PISTE pour lois, décrets et jurisprudence.</div>"; }''',
'''function showVeille(){ document.getElementById("app").innerHTML = "<h1>📚 Dernières lois</h1><div class='card'>Module veille juridique : connexion future à Légifrance/PISTE pour lois, décrets et jurisprudence.</div>"; }

function showStats(){
  document.getElementById("app").innerHTML = `
    <h1>📊 Statistiques Web / Référencement</h1>
    <div class="cards">
      <div class="card"><h2>0</h2><p>Visiteurs aujourd'hui</p></div>
      <div class="card"><h2>0</h2><p>Prospects entrants</p></div>
      <div class="card"><h2>0</h2><p>Conversions</p></div>
    </div>
    <div class="card">
      <h3>Sources de trafic</h3>
      <p>Google, réseaux sociaux, accès direct, campagnes publicitaires.</p>
    </div>
    <div class="card">
      <h3>SEO / Référencement</h3>
      <p>Suivi futur : Google Search Console, mots-clés, pages les plus visitées, positionnement.</p>
    </div>
    <div class="card">
      <h3>Objectif</h3>
      <p>Identifier les visiteurs, mesurer les demandes clients, suivre les prospects et améliorer le référencement du cabinet.</p>
    </div>
  `;
}'''
)

p.write_text(s)
PY

sudo systemctl restart nginx

git add .
git commit -m "Add web statistics and SEO module" || true
git push || true

echo "OK : recharge http://51.255.161.205 avec Ctrl+F5"
