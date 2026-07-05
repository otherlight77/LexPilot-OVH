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
