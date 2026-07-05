using LexPilot.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/mail-ai")]
public class MailAiController : ControllerBase
{
    private readonly AppDbContext _db;

    public MailAiController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet("inbox")]
    public IActionResult Inbox([FromQuery] string? search = null)
    {
        var mails = new[]
        {
            new { id = "m1", from = "jean.dupont@test.fr", subject = "Documents divorce", body = "Bonjour, voici les pièces pour mon divorce.", date = DateTime.UtcNow.AddHours(-1) },
            new { id = "m2", from = "sophie.martin@test.fr", subject = "Licenciement", body = "Je vous transmets mon contrat de travail et mon courrier de licenciement.", date = DateTime.UtcNow.AddHours(-3) },
            new { id = "m3", from = "greffe@justice.fr", subject = "Convocation audience TJ Lille", body = "Convocation pour audience civile.", date = DateTime.UtcNow.AddHours(-5) }
        };

        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.ToLower();
            mails = mails.Where(x =>
                x.from.ToLower().Contains(q) ||
                x.subject.ToLower().Contains(q) ||
                x.body.ToLower().Contains(q)).ToArray();
        }

        return Ok(mails);
    }

    [HttpGet("suggest-dossier")]
    public async Task<IActionResult> SuggestDossier([FromQuery] string text)
    {
        var dossiers = await _db.Dossiers
            .Include(x => x.Client)
            .Where(x => !x.IsArchived)
            .Take(100)
            .ToListAsync();

        var lower = text.ToLower();

        var best = dossiers
            .Select(d => new
            {
                d.Id,
                d.Numero,
                d.Titre,
                d.TypeAffaire,
                Score =
                    (lower.Contains(d.Numero.ToLower()) ? 10 : 0) +
                    (lower.Contains(d.Titre.ToLower()) ? 8 : 0) +
                    (lower.Contains(d.TypeAffaire.ToLower()) ? 4 : 0) +
                    (d.Client != null && lower.Contains(d.Client.LastName.ToLower()) ? 7 : 0) +
                    (d.Client != null && lower.Contains(d.Client.FirstName.ToLower()) ? 5 : 0)
            })
            .OrderByDescending(x => x.Score)
            .FirstOrDefault();

        return Ok(new
        {
            status = "ok",
            engine = "LexPilot IA locale V1",
            suggestion = best,
            message = best == null || best.Score == 0
                ? "Aucun dossier évident détecté."
                : $"Suggestion : {best.Numero} - {best.Titre}"
        });
    }

    [HttpPost("classify")]
    public IActionResult Classify([FromBody] ClassifyMailRequest request)
    {
        return Ok(new
        {
            status = "classified",
            mailId = request.MailId,
            dossierId = request.DossierId,
            message = "Mail classé virtuellement dans le dossier. Stockage réel prévu V2."
        });
    }
}

public record ClassifyMailRequest(string MailId, Guid DossierId);
