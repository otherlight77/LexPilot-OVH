using Microsoft.AspNetCore.Mvc;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/outlook")]
public class OutlookController : ControllerBase
{
    [HttpGet("test")]
    public IActionResult Test()
    {
        var tenant = Environment.GetEnvironmentVariable("OUTLOOK_TENANT_ID");
        var clientId = Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_ID");
        var clientSecret = Environment.GetEnvironmentVariable("OUTLOOK_CLIENT_SECRET");

        if (string.IsNullOrWhiteSpace(tenant) || string.IsNullOrWhiteSpace(clientId) || string.IsNullOrWhiteSpace(clientSecret))
        {
            return Ok(new
            {
                status = "configuration_missing",
                service = "Microsoft Graph / Outlook",
                message = "Identifiants Microsoft 365 non configurés. Le module est prêt côté LexPilot."
            });
        }

        return Ok(new
        {
            status = "configured",
            service = "Microsoft Graph / Outlook",
            message = "Identifiants détectés. Prochaine étape : OAuth + lecture emails."
        });
    }
}
