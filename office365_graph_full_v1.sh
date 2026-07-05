#!/bin/bash
set -e

cd /opt/lexpilot-ovh

mkdir -p src/LexPilot.Api/Services/Office365
mkdir -p data

cat > src/LexPilot.Api/Services/Office365/Office365TokenStore.cs <<'CS'
using System.Text.Json;

namespace LexPilot.Api.Services.Office365;

public class Office365TokenStore
{
    private readonly string _file = "/opt/lexpilot-ovh/data/office365_tokens.json";

    public async Task SaveAsync(Office365TokenData data)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_file)!);
        var json = JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true });
        await File.WriteAllTextAsync(_file, json);
    }

    public async Task<Office365TokenData?> LoadAsync()
    {
        if (!File.Exists(_file)) return null;
        var json = await File.ReadAllTextAsync(_file);
        return JsonSerializer.Deserialize<Office365TokenData>(json);
    }
}

public class Office365TokenData
{
    public string AccessToken { get; set; } = "";
    public string RefreshToken { get; set; } = "";
    public DateTime ExpiresAtUtc { get; set; }
}
CS

cat > src/LexPilot.Api/Controllers/Office365GraphController.cs <<'CS'
using System.Net.Http.Headers;
using System.Text.Json;
using LexPilot.Api.Services.Office365;
using Microsoft.AspNetCore.Mvc;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/office365-graph")]
public class Office365GraphController : ControllerBase
{
    private readonly IHttpClientFactory _httpFactory;
    private readonly Office365TokenStore _tokenStore;

    public Office365GraphController(IHttpClientFactory httpFactory, Office365TokenStore tokenStore)
    {
        _httpFactory = httpFactory;
        _tokenStore = tokenStore;
    }

    [HttpGet("config")]
    public IActionResult Config()
    {
        return Ok(new
        {
            tenantId = Mask(Environment.GetEnvironmentVariable("OUTLOOK_TENANT_ID")),
            clientId = Mask(Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_ID")),
            clientSecret = string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_SECRET")) ? "missing" : "configured",
            redirectUri = Environment.GetEnvironmentVariable("OFFICE365_REDIRECT_URI") ?? "missing"
        });
    }

    [HttpGet("login-url")]
    public IActionResult LoginUrl()
    {
        var tenant = Environment.GetEnvironmentVariable("OUTLOOK_TENANT_ID") ?? "common";
        var clientId = Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_ID");
        var redirectUri = Environment.GetEnvironmentVariable("OFFICE365_REDIRECT_URI");

        if (string.IsNullOrWhiteSpace(clientId) || string.IsNullOrWhiteSpace(redirectUri))
            return BadRequest("OUTLOOK_CLIENT_ID ou OFFICE365_REDIRECT_URI manquant.");

        var scopes = Uri.EscapeDataString("offline_access openid profile email User.Read Mail.Read Mail.Send Calendars.ReadWrite Contacts.Read Files.ReadWrite");
        var url =
            $"https://login.microsoftonline.com/{tenant}/oauth2/v2.0/authorize" +
            $"?client_id={Uri.EscapeDataString(clientId)}" +
            $"&response_type=code" +
            $"&redirect_uri={Uri.EscapeDataString(redirectUri)}" +
            $"&response_mode=query" +
            $"&scope={scopes}";

        return Ok(new { url });
    }

    [HttpGet("callback")]
    public async Task<IActionResult> Callback([FromQuery] string code)
    {
        var tenant = Environment.GetEnvironmentVariable("OUTLOOK_TENANT_ID") ?? "common";
        var clientId = Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_ID");
        var clientSecret = Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_SECRET");
        var redirectUri = Environment.GetEnvironmentVariable("OFFICE365_REDIRECT_URI");

        if (string.IsNullOrWhiteSpace(clientId) || string.IsNullOrWhiteSpace(clientSecret) || string.IsNullOrWhiteSpace(redirectUri))
            return BadRequest("Configuration Microsoft Graph incomplète.");

        var client = _httpFactory.CreateClient();

        var form = new Dictionary<string, string>
        {
            ["client_id"] = clientId,
            ["client_secret"] = clientSecret,
            ["code"] = code,
            ["redirect_uri"] = redirectUri,
            ["grant_type"] = "authorization_code",
            ["scope"] = "offline_access openid profile email User.Read Mail.Read Mail.Send Calendars.ReadWrite Contacts.Read Files.ReadWrite"
        };

        var res = await client.PostAsync(
            $"https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token",
            new FormUrlEncodedContent(form));

        var raw = await res.Content.ReadAsStringAsync();
        if (!res.IsSuccessStatusCode) return BadRequest(raw);

        using var doc = JsonDocument.Parse(raw);
        var accessToken = doc.RootElement.GetProperty("access_token").GetString() ?? "";
        var refreshToken = doc.RootElement.TryGetProperty("refresh_token", out var rt) ? rt.GetString() ?? "" : "";
        var expiresIn = doc.RootElement.TryGetProperty("expires_in", out var exp) ? exp.GetInt32() : 3600;

        await _tokenStore.SaveAsync(new Office365TokenData
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            ExpiresAtUtc = DateTime.UtcNow.AddSeconds(expiresIn - 60)
        });

        return Content("<h1>Office 365 connecté</h1><p>Tu peux revenir dans LexPilot.</p>", "text/html");
    }

    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        return await GraphGet("https://graph.microsoft.com/v1.0/me");
    }

    [HttpGet("messages")]
    public async Task<IActionResult> Messages()
    {
        return await GraphGet("https://graph.microsoft.com/v1.0/me/messages?$top=10&$select=id,subject,from,receivedDateTime,hasAttachments");
    }

    [HttpGet("events")]
    public async Task<IActionResult> Events()
    {
        return await GraphGet("https://graph.microsoft.com/v1.0/me/events?$top=10&$select=id,subject,start,end,location");
    }

    [HttpGet("contacts")]
    public async Task<IActionResult> Contacts()
    {
        return await GraphGet("https://graph.microsoft.com/v1.0/me/contacts?$top=10&$select=id,displayName,emailAddresses");
    }

    [HttpGet("drive")]
    public async Task<IActionResult> Drive()
    {
        return await GraphGet("https://graph.microsoft.com/v1.0/me/drive/root/children?$top=10");
    }

    [HttpGet("word")]
    public IActionResult Word()
    {
        return Ok(new
        {
            module = "Word",
            features = new[]
            {
                "Modèles DOCX",
                "Courriers automatiques",
                "Fusion client / dossier",
                "Export PDF",
                "Stockage OneDrive / SharePoint"
            }
        });
    }

    private async Task<IActionResult> GraphGet(string url)
    {
        var token = await _tokenStore.LoadAsync();
        if (token == null || string.IsNullOrWhiteSpace(token.AccessToken))
            return Unauthorized(new { status = "not_connected", message = "Office 365 non connecté." });

        var client = _httpFactory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.AccessToken);

        var res = await client.GetAsync(url);
        var raw = await res.Content.ReadAsStringAsync();

        return Content(raw, "application/json");
    }

    private static string Mask(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return "missing";
        if (value.Length <= 8) return "configured";
        return value[..4] + "..." + value[^4..];
    }
}
CS

python3 - <<'PY'
from pathlib import Path
p = Path("src/LexPilot.Api/Program.cs")
s = p.read_text()
if "Office365TokenStore" not in s:
    s = s.replace("using Microsoft.EntityFrameworkCore;", "using Microsoft.EntityFrameworkCore;\nusing LexPilot.Api.Services.Office365;")
if "AddHttpClient" not in s:
    s = s.replace("builder.Services.AddControllers();", "builder.Services.AddControllers();\nbuilder.Services.AddHttpClient();\nbuilder.Services.AddSingleton<Office365TokenStore>();")
p.write_text(s)
PY

python3 - <<'PY'
from pathlib import Path
p = Path("web/index.html")
s = p.read_text()

office_js = r'''
async function showOffice365(){
  const cfg = await (await fetch("/api/office365-graph/config")).json();
  app.innerHTML = `
    <h1>📨 Office 365 / Microsoft Graph</h1>
    <div class="cards">
      <div class="card"><h2>${cfg.clientId}</h2><p>Client ID</p></div>
      <div class="card"><h2>${cfg.clientSecret}</h2><p>Client Secret</p></div>
      <div class="card"><h2>${cfg.redirectUri}</h2><p>Redirect URI</p></div>
    </div>
    <div class="card">
      <button onclick="connectOffice365()">Connecter Office 365</button>
      <button onclick="loadGraphMe()">Compte</button>
      <button onclick="loadGraphMessages()">Mails</button>
      <button onclick="loadGraphEvents()">Agenda</button>
      <button onclick="loadGraphContacts()">Contacts</button>
      <button onclick="loadGraphDrive()">OneDrive</button>
      <button onclick="loadWordModule()">Word</button>
    </div>
    <div id="officeResult" class="card">Module prêt.</div>
  `;
}

async function connectOffice365(){
  const r = await fetch("/api/office365-graph/login-url");
  const d = await r.json();
  if(d.url) window.location.href = d.url;
  else alert(JSON.stringify(d));
}

async function loadGraphMe(){ officeResult.innerText = JSON.stringify(await (await fetch("/api/office365-graph/me")).json(), null, 2); }
async function loadGraphMessages(){ officeResult.innerText = JSON.stringify(await (await fetch("/api/office365-graph/messages")).json(), null, 2); }
async function loadGraphEvents(){ officeResult.innerText = JSON.stringify(await (await fetch("/api/office365-graph/events")).json(), null, 2); }
async function loadGraphContacts(){ officeResult.innerText = JSON.stringify(await (await fetch("/api/office365-graph/contacts")).json(), null, 2); }
async function loadGraphDrive(){ officeResult.innerText = JSON.stringify(await (await fetch("/api/office365-graph/drive")).json(), null, 2); }
async function loadWordModule(){ officeResult.innerText = JSON.stringify(await (await fetch("/api/office365-graph/word")).json(), null, 2); }
'''

start = s.find("function showOffice365()")
if start != -1:
    end = s.find("function showAgenda()", start)
    if end != -1:
        s = s[:start] + office_js + "\n" + s[end:]
else:
    s = s.replace("showDashboard();", office_js + "\nshowDashboard();")

p.write_text(s)
PY

dotnet build
dotnet publish src/LexPilot.Api/LexPilot.Api.csproj -c Release -o /opt/lexpilot-ovh/publish/api

sudo systemctl restart lexpilot-api
sudo systemctl restart nginx

sleep 5

curl http://localhost/api/office365-graph/config
echo ""

git add .
git commit -m "Add Microsoft Graph Office365 OAuth module" || true
git push || true

echo "OK : module Office 365 Graph installé."
