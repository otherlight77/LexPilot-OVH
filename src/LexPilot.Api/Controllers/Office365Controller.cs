using Microsoft.AspNetCore.Mvc;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/office365")]
public class Office365Controller : ControllerBase
{
    [HttpGet("status")]
    public IActionResult Status()
    {
        var tenantId = Environment.GetEnvironmentVariable("OUTLOOK_TENANT_ID");
        var clientId = Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_ID");
        var clientSecret = Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_SECRET");

        var configured =
            !string.IsNullOrWhiteSpace(tenantId) &&
            !string.IsNullOrWhiteSpace(clientId) &&
            !string.IsNullOrWhiteSpace(clientSecret);

        return Ok(new
        {
            service = "Microsoft 365 / Outlook",
            configured,
            status = configured ? "ready" : "missing_configuration",
            features = new[]
            {
                "Lecture des emails",
                "Envoi de mails",
                "Pièces jointes",
                "Classement dans les dossiers",
                "Synchronisation agenda",
                "Résumé IA des échanges"
            }
        });
    }

    [HttpGet("inbox-preview")]
    public IActionResult InboxPreview()
    {
        return Ok(new[]
        {
            new { from = "client@example.com", subject = "Transmission des pièces", dossier = "À classer", date = DateTime.UtcNow },
            new { from = "tribunal@example.com", subject = "Convocation audience", dossier = "À détecter", date = DateTime.UtcNow.AddHours(-2) },
            new { from = "confrere@example.com", subject = "Conclusions adverses", dossier = "À rattacher", date = DateTime.UtcNow.AddHours(-5) }
        });
    }
}
