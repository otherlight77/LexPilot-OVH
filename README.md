# LexPilot OVH

Base propre LexPilot OVH en .NET 10.

Lancer :

```bash
docker compose up -d
dotnet run --project src/LexPilot.Api/LexPilot.Api.csproj --urls http://0.0.0.0:5128
curl http://localhost:5128/health
curl http://localhost:5128/api/dashboard
