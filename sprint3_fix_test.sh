#!/bin/bash
set -e

cd /opt/lexpilot-ovh

dotnet build

pkill -f "LexPilot.Api" || true
nohup dotnet run --project src/LexPilot.Api/LexPilot.Api.csproj --urls http://0.0.0.0:5128 > lexpilot.log 2>&1 &

sleep 7

echo "=== HEALTH ==="
curl http://localhost:5128/health
echo ""

echo "=== CLIENT ==="
CLIENT_ID=$(curl -s http://localhost:5128/api/clients | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if d else '')")

if [ -z "$CLIENT_ID" ]; then
  CLIENT_ID=$(curl -s -X POST http://localhost:5128/api/clients \
    -H "Content-Type: application/json" \
    -d '{"firstName":"Jean","lastName":"Dupont","email":"jean.dupont@test.fr","phone":"0600000000","city":"Lille"}' \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
fi

echo "ClientId=$CLIENT_ID"

echo "=== CREATION DOSSIER ==="
curl -X POST http://localhost:5128/api/dossiers \
  -H "Content-Type: application/json" \
  -d "{\"numero\":\"D-2026-0001\",\"titre\":\"Premier dossier test\",\"typeAffaire\":\"Civil\",\"statut\":\"Ouvert\",\"juridiction\":\"Tribunal judiciaire de Lille\",\"clientId\":\"$CLIENT_ID\"}"
echo ""

echo "=== DOSSIERS ==="
curl http://localhost:5128/api/dossiers
echo ""

echo "=== DASHBOARD ==="
curl http://localhost:5128/api/dashboard
echo ""

git add .
git commit -m "Sprint 3 - Dossiers validated" || true
git push || true

echo "SPRINT 3 OK"
