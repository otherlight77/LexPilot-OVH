using Microsoft.AspNetCore.Mvc;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/legifrance")]
public class LegifranceController : ControllerBase
{
    [HttpGet("test")]
    public IActionResult Test()
    {
        var clientId = Environment.GetEnvironmentVariable("LEGIFRANCE_CLIENT_ID");
        var clientSecret = Environment.GetEnvironmentVariable("LEGIFRANCE_CLIENT_SECRET");

        if (string.IsNullOrWhiteSpace(clientId) || string.IsNullOrWhiteSpace(clientSecret))
        {
            return Ok(new
            {
                status = "configuration_missing",
                service = "Legifrance / PISTE",
                message = "Identifiants API Légifrance non configurés. Le module est prêt côté LexPilot."
            });
        }

        return Ok(new
        {
            status = "configured",
            service = "Legifrance / PISTE",
            message = "Identifiants détectés. Prochaine étape : appel OAuth + recherche juridique."
        });
    }
}
