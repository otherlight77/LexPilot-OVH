#!/bin/bash
set -e

cd /opt/lexpilot-ovh

mkdir -p web

cat > web/index.html <<'HTML'
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>LexPilot Enterprise</title>
  <style>
    body { margin:0; font-family:Arial; background:#f4f6f8; }
    header { background:#111827; color:white; padding:18px; font-size:24px; }
    .layout { display:flex; min-height:100vh; }
    nav { width:230px; background:#1f2937; color:white; padding:20px; }
    nav div { padding:12px; cursor:pointer; border-bottom:1px solid #374151; }
    main { flex:1; padding:25px; }
    .cards { display:flex; gap:20px; margin-bottom:25px; }
    .card { background:white; padding:20px; border-radius:10px; box-shadow:0 2px 8px #ccc; flex:1; }
    table { width:100%; border-collapse:collapse; background:white; }
    th,td { padding:12px; border-bottom:1px solid #ddd; text-align:left; }
    th { background:#e5e7eb; }
    button { padding:10px 14px; background:#2563eb; color:white; border:0; border-radius:6px; cursor:pointer; }
    input { padding:10px; margin:5px; }
  </style>
</head>
<body>
<header>⚖️ LexPilot Enterprise V1</header>

<div class="layout">
  <nav>
    <div onclick="showDashboard()">📊 Dashboard</div>
    <div onclick="loadClients()">👥 Clients</div>
    <div onclick="loadDossiers()">📁 Dossiers</div>
    <div onclick="loadDocuments()">📄 Documents</div>
    <div>🤖 IA</div>
    <div>⚙️ Paramètres</div>
  </nav>

  <main id="app">
    Chargement...
  </main>
</div>

<script>
const API = "http://51.255.161.205:5128";

async function showDashboard() {
  const r = await fetch(API + "/api/dashboard");
  const d = await r.json();
  document.getElementById("app").innerHTML = `
    <h1>Dashboard</h1>
    <div class="cards">
      <div class="card"><h2>${d.clients}</h2><p>Clients</p></div>
      <div class="card"><h2>${d.dossiers}</h2><p>Dossiers</p></div>
      <div class="card"><h2>${d.documents}</h2><p>Documents</p></div>
    </div>
    <div class="card"><b>Statut :</b> ${d.message}</div>
  `;
}

async function loadClients() {
  const r = await fetch(API + "/api/clients");
  const data = await r.json();
  let rows = data.map(x => `<tr><td>${x.firstName}</td><td>${x.lastName}</td><td>${x.email ?? ""}</td><td>${x.city ?? ""}</td></tr>`).join("");
  document.getElementById("app").innerHTML = `
    <h1>Clients</h1>
    <div class="card">
      <input id="fn" placeholder="Prénom">
      <input id="ln" placeholder="Nom">
      <input id="em" placeholder="Email">
      <button onclick="createClient()">Ajouter client</button>
    </div>
    <br>
    <table><tr><th>Prénom</th><th>Nom</th><th>Email</th><th>Ville</th></tr>${rows}</table>
  `;
}

async function createClient() {
  await fetch(API + "/api/clients", {
    method:"POST",
    headers:{ "Content-Type":"application/json" },
    body: JSON.stringify({
      firstName: document.getElementById("fn").value,
      lastName: document.getElementById("ln").value,
      email: document.getElementById("em").value,
      city: "Lille"
    })
  });
  loadClients();
}

async function loadDossiers() {
  const r = await fetch(API + "/api/dossiers");
  const data = await r.json();
  let rows = data.map(x => `<tr><td>${x.numero}</td><td>${x.titre}</td><td>${x.typeAffaire}</td><td>${x.statut}</td></tr>`).join("");
  document.getElementById("app").innerHTML = `
    <h1>Dossiers</h1>
    <table><tr><th>Numéro</th><th>Titre</th><th>Type</th><th>Statut</th></tr>${rows}</table>
  `;
}

async function loadDocuments() {
  const r = await fetch(API + "/api/documents");
  const data = await r.json();
  let rows = data.map(x => `<tr><td>${x.originalFileName}</td><td>${x.category ?? ""}</td><td>${x.sizeBytes}</td></tr>`).join("");
  document.getElementById("app").innerHTML = `
    <h1>Documents</h1>
    <table><tr><th>Nom</th><th>Catégorie</th><th>Taille</th></tr>${rows}</table>
  `;
}

showDashboard();
</script>
</body>
</html>
HTML

pkill -f "python3 -m http.server 8080" || true
nohup python3 -m http.server 8080 --directory web > web.log 2>&1 &

git add .
git commit -m "Sprint 5 - Web interface dashboard clients dossiers documents" || true
git push || true

echo "Interface disponible : http://51.255.161.205:8080"
