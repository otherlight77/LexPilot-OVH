#!/bin/bash
set -e

cd /opt/lexpilot-ovh

python3 - <<'PY'
from pathlib import Path
p = Path("web/index.html")
s = p.read_text()

s = s.replace(
'''    <div>🤖 IA</div>
    <div>⚙️ Paramètres</div>''',
'''    <div onclick="showMail()">📧 Mail</div>
    <div onclick="showAgenda()">📅 Agenda</div>
    <div onclick="showScanner()">📠 Scanner / OCR</div>
    <div onclick="showVoice()">🎙️ Dictée vocale</div>
    <div onclick="showRpva()">⚖️ RPVA / e-Barreau</div>
    <div onclick="showVeille()">📚 Dernières lois</div>
    <div>🤖 IA</div>
    <div>⚙️ Paramètres</div>'''
)

s = s.replace(
'''showDashboard();
</script>''',
'''
function showMail(){ document.getElementById("app").innerHTML = "<h1>📧 Mail</h1><div class='card'>Module messagerie : réception, classement par dossier, pièces jointes, suivi des échanges.</div>"; }
function showAgenda(){ document.getElementById("app").innerHTML = "<h1>📅 Agenda</h1><div class='card'>Module agenda : audiences, rendez-vous, échéances, rappels, synchronisation future Outlook/Google.</div>"; }
function showScanner(){ document.getElementById("app").innerHTML = "<h1>📠 Scanner / OCR</h1><div class='card'>Module scanner : dépôt de PDF/scans, OCR, classement automatique dans les dossiers.</div>"; }
function showVoice(){ document.getElementById("app").innerHTML = "<h1>🎙️ Dictée vocale</h1><div class='card'>Module dictée : notes vocales, transcription, génération de brouillons de courriers.</div>"; }
function showRpva(){ document.getElementById("app").innerHTML = "<h1>⚖️ RPVA / e-Barreau</h1><div class='card'>Module RPVA : passerelle prévue avec e-Barreau/CNB après autorisation éditeur.</div>"; }
function showVeille(){ document.getElementById("app").innerHTML = "<h1>📚 Dernières lois</h1><div class='card'>Module veille juridique : connexion future à Légifrance/PISTE pour lois, décrets et jurisprudence.</div>"; }

showDashboard();
</script>'''
)

p.write_text(s)
PY

git add .
git commit -m "Sprint 5 - Add mail agenda OCR voice RPVA legal watch modules" || true
git push || true

echo "OK : recharge http://51.255.161.205:8080"
